# 创面评估系统 — 微信小程序版技术设计

> 2026-09-09 起 · 从 Flutter 医护端迁移为微信小程序 + 腾讯云开发（CloudBase）
> 小程序原始 ID：`gh_8bf47d7de1c8` · 云环境：`wound-gcp-d2gh9r44ta15f1664`（ap-shanghai）
> **2026-09-10 更新：环境实为 PG 模式（无文档数据库），数据层已从云文档库切换为 PostgreSQL。**

## 1. 总体架构

```
微信小程序（原生框架）
   │  wx.cloud.callFunction（微信私有通道，免域名 / 免备案 / 自动 HTTPS）
   ▼
云函数 api（Node.js 18，单函数 action 路由，24 个 action）
   │  ├─ @cloudbase/node-sdk  app.rdb()  ──►  CloudBase PostgreSQL（PostgREST 风格）
   │  │     走平台网关 + 环境内临时凭据，无需连接串 / VPC / API Key
   │  └─ wx-server-sdk  getWXContext()  ──►  OPENID（稳定用户标识）
   ▼
PostgreSQL 实例 pgdb-6vs5173p · schema public（11 张业务表）
```

**为什么用云函数而不是云托管容器**：无状态 HTTP API、无长连接、无自定义运行时
→ 按 CloudBase 官方决策树选云函数；小程序场景走 OPENID 天然免登录，
免域名免备案（自建 Lighthouse 需要 ICP 备案 1–2 周，不满足"投入使用"）。

**为什么是 PostgreSQL 而不是文档数据库**：本环境创建时选中了 PG 模式
（`RuntimeBackends.postgresql === true`），环境内不存在文档数据库实例，
所有 `db.collection()` 调用返回 `-501001`。PG 模式是更优选择——创面评估是强关系型
数据（患者→创面→评估→CRF），且审计哈希链需要严格顺序与事务语义。

## 2. 身份与 RBAC

- **OPENID = 稳定用户标识**。首次登录输入工号（如 `pi_demo`）绑定。
- `users` 表：`{ id, username, display_name, role, openid, center_ids, active }`
- 角色派生规则与 Flutter 版一致：`pi_*`→PI、`subi_*`→SubI、`crc_*`→CRC、
  `sponsor_*`→Sponsor、`irb_*`→IRB、`admin_*`→Admin，默认 CRC。
- 6 角色权限矩阵照搬 `代码/mobile 安卓/lib/models/user_role.dart`（W4.6 收紧版），
  见 `cloudfunctions/api/rbac.js`：

| 角色 | 权限数 | 要点 |
|---|---|---|
| PI | 14 | 全研究侧权限（不含 data:destroy） |
| SubI | 8 | 可做医学判断，无锁定签字权 |
| CRC | 2 | 只读（audit:read / pdf:export） |
| Sponsor | 2 | 仅聚合统计 + 监查查轨迹（GCP §5） |
| IRB | 3 | 仅伦理相关（GCP §6） |
| Admin | 6 | 系统管理，**不可做医学判断**（PIPL §6） |

- 服务端逐 action `rbac.can()` 守门：**医学判断必须研究者本人**（GCP §4）
  → 仅 PI/SubI 可建评估；**锁定签字仅 PI**（21 CFR Part 11）
- 越权访问一律 403 并记审计 `accessDenied`

## 3. 数据库（PostgreSQL · schema public）

11 张表，迁移脚本在 `cloudbase/migrations/`（用 `tcb db pg migration up` 应用）。

| 表 | 说明 | 关键列 |
|---|---|---|
| users | 账号↔OPENID↔角色 | username, display_name, role, openid, center_ids |
| patients | 受试者主表（真名不进主表） | subject_code(鉴认代码), mrn, gender, birth_year, protocol_id, center_id, consent_status |
| wounds | 创面部位 | patient_id, label, body_part |
| assessments | 评估记录 | wound_id, patient_id, length_cm, width_cm, area_cm2, tissue_json, vss_score, crf(jsonb), status(pending/locked), locked_by, locked_at, retention_until |
| consents | 知情同意 | patient_id, mode(E_CONSENT/PAPER_PHOTO), status, photo_file_id, witness_name, reviewed_by |
| centers | 研究中心 | code, name, lead_pi_name, pi_contact, irb_number, consent_mode |
| protocols | 试验方案 | code, name, version, sponsor, phase, status |
| protocol_docs | 方案文档元数据 | protocol_id, file_name, file_ext, file_size_bytes, version |
| devices | 试用器械追溯 | code, name, batch_no, status, allocated_to |
| audit_logs | GCP 审计哈希链 | seq(bigserial), ts, **ts_iso**, actor, role, action, target, detail(jsonb), prev_hash, hash |
| counters | 鉴认代码序列器 | id, seq → ZW0001… |

### 审计哈希链（NMPA 2022 §57–63 / ALCOA+）

```
hash = SHA256(prevHash | ts_iso | actor | action | target | stableStringify(detail))
```

- 链尾即首条（`prevHash = 'GENESIS'`），任何篡改导致后续 hash 校验断裂
- `stableStringify()` 键排序 —— jsonb 回读会重排键顺序，不排序必然校验失败
- **⚠️ 哈希必须覆盖 `ts_iso` 而非 `ts`**：`ts` 是 `timestamptz`，回读格式随时区变化
  （写入 `...382Z` ↔ 回读 `...382+08`），用它做哈希会导致全链校验在 seq=1 断裂。
  `ts_iso` 保存写入时的 ISO 原文字符串，是**权威时间戳**；`ts` 仅用于时间区间查询。
- 校验入口：`auditVerify` action（PI / SubI / CRC / Sponsor / IRB / Admin 均可读）

### 数据库角色与授权（**重要，避免踩坑**）

云函数经平台网关访问 PG 时，凭据 JWT **不带 `role` 声明**，PostgREST 落到 `anon` 角色。
CloudBase 官方角色映射：

| 凭据 | PG 角色 | 用途 |
|---|---|---|
| Publishable Key | `anon` | 前端安全 |
| User access token | `authenticated` | 已登录用户 |
| **API Key** | **`service_role`** | **后端专用（官方推荐）** |

**当前实现**：本环境 **没有签发任何 API Key**（`DescribeApiKeyList` 返回 0），
且 CLI 明确提示 `api_key 类型暂未开放` —— 官方推荐的 `service_role` 通道暂时不可用。
因此采取务实方案：**给 `anon` 授予业务表的读写权限**（`cloudbase/migrations/` 之外，
已通过 `tcb db execute` 执行）：

```sql
GRANT INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON ALL TABLES IN SCHEMA public TO anon;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO anon;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO anon;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO anon;
```

**风险与迁移路径**：
- 风险等级：低。本环境无 publishable key，外部无法签出 `anon` 凭据；
  `anon` 实际只有平台内部的云函数客户端凭据能触达。数据安全第一道防线是
  云函数内的 RBAC + 审计（见 §2），数据库角色是第二道防线。
- **上线前必做**：待 `api_key` 类型开放后，创建 API Key → 注入云函数环境变量
  `CLOUDBASE_API_KEY` → `pg.js` 改为 `Authorization: Bearer ${process.env.CLOUDBASE_API_KEY}`
  直连 REST → 回收 `anon` 的写权限。参见官方 `pg-mode-overview` / `auth-and-rls` 文档。

## 4. 数据合规要点（与 Flutter 医护端对齐）

- **真名不进主表**：小程序端不采集受试者姓名，主表仅鉴认代码 + 病案号；
  病案号按角色脱敏（CRC / Sponsor / IRB 返回空 + `mrnMasked: '—'`）
- **照片**：`wx.chooseMedia` 压缩上传（端上压缩天然剥离 EXIF GPS）→ 云存储；
  同时记录拍摄设备型号（deviceFingerprint 简版）
- **留存期**：评估锁定时间 + 10 年（NMPA §63），工作台 / 详情页显示留存截止日
- **eConsent**：V1 只做 B 通道（纸质件拍照 + 见证人 + PI 审核），A 通道电子签名画板下版
- **单位制**：全线 cm / cm²（面积由长×宽后端自动计算，前端不可直接传面积）
- **数据最小化**：Sponsor 只见聚合统计；IRB 只见伦理材料（受试者以鉴认代码呈现）；
  Admin 不可做医学判断

## 5. 页面清单（11 页）

| 页面 | 角色 | 功能 |
|---|---|---|
| login | 全部 | 工号绑定 OPENID |
| home | 分角色 | 临床工作台 / Sponsor 统计 / IRB 待审 / Admin 管理 + 留存期卡 |
| patients | PI/SubI/CRC | 列表 + 新增（鉴认代码自动生成） |
| patient-detail | PI/SubI/CRC | 部位列表 + 新增部位 + 知情状态 |
| wound-detail | PI/SubI/CRC | 评估历史 + 留存期 + 新增评估入口 |
| capture | PI/SubI | 拍照 / 相册 → 云存储 |
| scale | PI/SubI | VSS 量表 + CRF 三态字段（ND/UN/NA） |
| sign | PI | PIN(123456) 二次鉴别 → 锁定（21 CFR Part 11 简版） |
| consent | PI/CRC/IRB | B 通道：拍照上传 / PI 审核 / IRB 查看 |
| trial | PI/Admin | 中心 / 方案文档 / 器械 |
| my | 全部 | 角色信息 / 权限列表 / 退出 |

## 6. 部署与运维

```bash
# 环境准备
export PATH="$HOME/.workbuddy/binaries/node/versions/22.12.0/bin:$PATH"
ENV=wound-gcp-d2gh9r44ta15f1664

# 1) 登录（凭据持久化，只需一次）
tcb login --flow device

# 2) 应用数据库迁移（幂等，自动跳过已应用项）
cd miniprogram
tcb db pg migration up -e $ENV

# 3) 部署云函数
tcb fn deploy api --force

# 4) 云端端到端自测（67 项断言：6 角色 + 主链路 + RBAC 反例 + 审计链）
node scripts/e2e-test.js

# 5) 查看日志
tcb fn log api
```

**小程序侧**：`project.config.json` 填 wx 开头 AppID；
`miniprogram/app.js` 中 `wx.cloud.init({ env: ENV_ID, traceUser: true })`。

**服务端自测通道**：`cloudbaserc.json` 里 `ALLOW_DEBUG_AUTH=1`
允许非小程序调用用工号直连（`__debugUser`）。**上线前必须置 0**。

## 7. 待办（V1 上线前必须人工确认）

- [ ] 用户提供 wx- 开头 AppID 并开通"云开发"（小程序后台 → 云开发 → 开通，绑定 wound-gcp）
- [ ] **关闭 `ALLOW_DEBUG_AUTH`**（`cloudbaserc.json` → `"0"`）并重新部署
- [ ] 申请 `api_key`（待平台开放）→ 切 `service_role` → 回收 `anon` 写权限
- [ ] 生产账号录入：真实 PI/CRC 工号 → Admin 在 users 表建账号（V1 手工，V2 接组织架构）
- [ ] PI demo PIN `123456` 上线前必须更换（接短信 OTP / 生物识别）
- [ ] 创面照片接入真实云存储（当前为 `cloud://` 占位 key）
- [ ] 审计日志留存量控：单表 10 年可能超限，需评估归档策略
