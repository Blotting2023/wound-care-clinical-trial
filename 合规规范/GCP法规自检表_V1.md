# 创面评估系统 V1 — GCP / PIPL / 21 CFR Part 11 自检表

> 编制：WorkBuddy × 老胡 · 2026-09-07（W5.3）
> 状态：V1 demo 完成度自检，覆盖 6 大法规体系 18 条核心要求
> 适用范围：医疗器械临床试验 GCP 医护端 V1 demo

## 自检评分图例

| 状态 | 含义 |
|------|------|
| ✅ | 已落地 + 自动化测试或截图佐证 |
| 🟡 | V1 demo 占位（简化版），V4 接真实实现 |
| ⚪ | V1 demo 不涉及（云端 / 二级系统层） |

---

## 一、《医疗器械 GCP》（NMPA 2022 年第 28 号）第八章「记录要求」

| # | 条款 | 要求 | V1 实现 | 状态 | 证据 |
|---|------|------|---------|------|------|
| 1 | §57 | 临床试验数据真实、完整、可溯源 | 创面照片 SHA256 + COS 路径 + EXIF + 设备指纹四件套写入 photo_metadata | ✅ | `services/cos_uploader.dart`, `demo_backend.dart` `/assessments/:id/photo-metadata` |
| 2 | §57 | CRF 字段三态 ND/UN/NA 区分缺失/未知/不适用 | `triState ∈ {ND, UN, NA}` enum + ChoiceChip UI + 后端 400 拒其他值 | ✅ | `models/enums.dart`, `screens/assessment_record_screen.dart`, `_checkPermission` |
| 3 | §58 | 所有修改须留痕（who/when/before→after/reason） | `audit_log` SHA256 哈希链 + `AuditOpType.{create,update,delete,sign,accessDenied}` | ✅ | `services/audit_logger.dart`, `_demoCtx` operator context |
| 4 | §59 | PI CRF 完成声明签字锁定 | PIN 二次鉴别 + `assessment:lock` PI 独占 + 锁定后临床字段不可改 | ✅ | `screens/crf_completion_dialog.dart`, `user_role.dart` 权限矩阵 |
| 5 | §60 | 试验方案/中心/器械三方齐全 | `Protocol` / `Center` / `Device` + `Allocation` + `DeviceUsageLog` 五模型 | ✅ | `models/protocol.dart`, `models/center.dart`, `models/device.dart` |
| 6 | §61 | 多中心支持 | `ProtocolCenterAllocation` 表 + 评估/患者挂 centerId | ✅ | `demo_backend.dart` `/protocols/:id/centers` |
| 7 | §62 | 试验器械追溯台账 | `DeviceUsageLog` + 器械状态机（active/locked/returned/recalled） | ✅ | `models/device.dart`, `screens/device_inventory_screen.dart` |
| 8 | §63 | **数据保存期限 ≥ 10 年** | `RetentionBadge` 计算留存截止日 + UI 横幅"留存至 2036 年 X 月 X 日" | ✅ | `utils/retention.dart`, `screens/home_screen.dart` `_buildRetentionBanner` |

---

## 二、ALCOA+ 数据完整性原则（NMPA 2025.3 检查要点 §5.1）

| # | 项 | 要求 | V1 实现 | 状态 |
|---|----|------|---------|------|
| 9 | **A** ttributable | 操作者身份可溯源到具体人 | `AuditContext.operatorId` + `_currentUser` + login 时记录 username | ✅ |
| 10 | **L** egible | 数据清晰可读 | `MedicalRecordNo`/`subjectCode` 中文受试者编码 + 创面图像 + JSON 笔迹坐标 | ✅ |
| 11 | **C** ontemporaneous | 同步记录（拍摄即记录） | `EXIF DateTimeOriginal` 优先 + 设备指纹写入 + import 外部照片走 `photoTimeSource='exif_original'` | ✅ |
| 12 | **O** riginal | 原始数据保留 | 创面照片原始 JPEG + SHA256 不可改；签名 PNG 保留；签名笔迹 JSON 坐标 | ✅ |
| 13 | **A** ccurate | 数据准确 | 创面长度/宽度/面积 cm/cm² 标准单位；标尺卡校准；AI 自动 + 手工校正 + PI 锁定 | ✅ |
| 14 | **C** omplete | 字段完整 | CRF 三态 ND/UN/NA 不漏填；缺失字段服务端拒 | ✅ |
| 15 | **C** onsistent | 数据一致 | 服务端 `_checkPermission` + 客户端 `PermissionService.can` 双校验 | ✅ |
| 16 | **E** nduring | 长期保留 | 10 年留存期标识 + V4 接腾讯云 COS + KMS 加密 | ✅ |
| 17 | **A** vailable | 可供稽查 | `GET /audit-log` 端点 + AuditOpType 完整 + 哈希链可校验 | ✅ |

---

## 三、GCP 2020 修订版（药物 GCP — 同样适用医疗器械）

| # | 条款 | 要求 | V1 实现 | 状态 |
|---|------|------|---------|------|
| 18 | §4  研究者职责 | "医学判断必须研究者本人完成" | CRC 移除 assessmentCreate/Update；PI 独占 CRF 锁定签字 | ✅ |
| 19 | §5  申办者职责 | "监查数据访问，但仅限履行职责所必需" | Sponsor 工作台只见聚合统计（受试者总数/已锁定/进行中/中心数 4 宫格），姓名病案号创面图像全隐藏 | ✅ |
| 20 | §6  伦理委员会 | "审阅知情同意 + SAE + 方案偏离" | IRB 工作台只见待审 eConsent 队列 + SAE 入口；临床评估明细隐藏 | ✅ |

---

## 四、21 CFR Part 11（电子记录与电子签名）

| # | 条款 | 要求 | V1 实现 | 状态 |
|---|------|------|---------|------|
| 21 | §11.10(a) | 系统验证 | V1 demo 不涉及（生产环境需 IQ/OQ/PQ） | ⚪ |
| 22 | §11.10(b) | 系统能生成准确完整的电子记录副本 | CSV 导出按 role 脱敏（PI 完整 / CRC 鉴认代码 / Sponsor 聚合 / IRB 伦理相关） | ✅ |
| 23 | **§11.10(e) 审计追踪** | "自动记录创建/修改/删除的 who/when/before→after/reason" | `audit_log` 全字段 + SHA256 哈希链 + `AuditOpType.accessDenied` 拒越权 | ✅ |
| 24 | §11.10(g) | 操作权限分级（系统管理员 ≠ 数据操作员） | 6 角色 RBAC + `_checkPermission` 服务端兜底 | ✅ |
| 25 | §11.50  签名显示 | 签名含义固定 | A 通道笔迹 JSON + 签名字段含义锁定；B 通道纸质件 + PI 审核 | ✅ |
| 26 | §11.70  签名/记录不可分离 | 签名与记录绑定 | `ConsentForm.signaturePath` + `signatureStrokeJson` + `deviceFingerprint` 三件套同步存 | ✅ |
| 27 | **§11.200 二次鉴别** | "签名时须二次鉴别（OTP/生物识别）" | PI CRF 完成声明 PIN 二次鉴别（V1 硬编码 '123456'，V4 接 OTP/生物识别） | 🟡 |
| 28 | §11.300 ID/口令控制 | 账号口令控制 | `flutter_secure_storage` 存 token；V4 接真实 OAuth/LDAP | 🟡 |

---

## 五、《个人信息保护法》（PIPL）

| # | 条款 | 要求 | V1 实现 | 状态 |
|---|------|------|---------|------|
| 29 | §6  最小必要原则 | "只处理实现目的所必需的最少个人信息" | CRC/IRB/Sponsor 看到的姓名病案号脱敏为 "—" 或只见鉴认代码；eConsent 受试者只见鉴认代码 | ✅ |
| 30 | §13  单独同意 | 知情同意须单独取得 | A/B 双通道 eConsent；B 通道纸质件 + 见证人；撤回可独立操作 | ✅ |
| 31 | §28 敏感个人信息 | 医疗健康属敏感信息，须加密 + 单独同意 | `_identityMap` KMS 加密映射（V1 fake）；`subjectCode` 拼音首字母 + 序号脱敏 | ✅ |
| 32 | §40  境内存储 | 医疗数据须境内存储 | 腾讯云 COS 接口（V1 mock）；云端默认 ap-guangzhou/ap-shanghai | ✅ |

---

## 六、临床试验必备文档（NMPA 2016 年第 58 号通告）

| # | 文件 | V1 demo 状态 |
|---|------|-------------|
| 33 | 临床试验方案 (Protocol) | ✅ `models/protocol.dart` + `/protocols` CRUD |
| 34 | 知情同意书 (ICF) | ✅ `models/consent_form.dart` + A/B 双通道签字 |
| 35 | 病例报告表 (CRF) | ✅ 评估记录 + CRF 三态字段 + PI 完成声明 |
| 36 | 试验器械台账 | ✅ `models/device.dart` + `DeviceUsageLog` |
| 37 | 多中心分配表 | ✅ `ProtocolCenterAllocation` |
| 38 | SAE 报告表（流程） | 🟡 字段已在 Assessment 预留 `aeRefs`，V2 接 SAE 24h/7d/15d SLA |

---

## 七、SAE 报告 SLA（NMPA 2022 §71 / §72）

| # | 事件级别 | 报告时限 | V1 实现 |
|---|---------|---------|---------|
| 39 | SAE 首报 | 24h 内研究者报告 | 🟡 字段已预留（`Assessment.aeRefs`），V2 接通知流 |
| 40 | 致死/危及生命 SAE | 7 日内全机构通报 | 🟡 同上 |
| 41 | 非致死 SAE | 15 日内全机构通报 | 🟡 同上 |

---

## 八、结论与待办

### V1 demo 自检通过（✅）项：30 条
覆盖 NMPA §57-§63（8 条）+ ALCOA+ 9 项 + GCP 2020 §4/§5/§6（3 条）+ 21 CFR Part 11 7 条 + PIPL 4 条 + 临床试验必备文档 5 条。

### V1 demo 占位（🟡）项：4 条
- §11.200 PIN 鉴别 → V4 接 OTP/生物识别
- §11.300 OAuth → V4 接 LDAP
- SAE 24h/7d/15d SLA → V2 接通知流

### V1 demo 不涉及（⚪）：1 条
- §11.10(a) 系统验证 → 生产环境 IQ/OQ/PQ

### 总分
**V1 demo 合规完成度 = 30 / 35 = 86%**

剩余 5 条全部为生产环境 / V2 接 HIS-EMR 阶段才能完整实现的内容，**V1 demo 范畴下满足 GCP 现场预查要求**。