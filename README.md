# 创面评估 GCP 临床试验医护端 App（V1 Demo）

> 面向医疗器械临床试验场景的创面评估 + 临床数据记录工具。
> **医护端使用**，配合 GCP 临床试验，配合**医疗器械 ALCOA+ 数据完整性**。
> 患者自拍端在 V2 规划中。

---

## 项目定位

| 维度 | 说明 |
|---|---|
| **使用对象** | 研究医生（PI / Sub-PI）、研究护士（CRC）、监查员（CRA / Monitor）、稽查员（Auditor） |
| **核心场景** | 创面拍照 + AI 辅助测量 + 临床量表录入 + CRF 字段 + 电子签名锁定 |
| **数据完整性** | 遵循 NMPA《医疗器械临床试验质量管理规范》(2022 年第 28 号) 第 57-63 条 + ALCOA+ 9 项 |
| **电子签名** | V3 规划支持 21 CFR Part 11 + 中国电子签名法；V1 用 PIN 二次鉴别 + 锁定 |
| **数据留存** | 完成或终止后 ≥ 10 年（GCP §63）；图像存腾讯云 COS 加密冷存储 |
| **隐私** | 真实姓名不进主表，仅加密映射表保存；受试者鉴认代码为主键（拼音首字母+4位序号） |

---

## 技术栈

- **Flutter** 3.47.2（macOS 桌面 + iOS 18.4 模拟器 + Android 真机）
- **状态管理** Provider
- **网络** Dio（统一 `ApiClient.instance` 单例 + Retry）
- **后端** V1 = 内存假后端（`DemoBackend`，所有数据飞掉重启就清）；V2 计划对接 HIS / EMR
- **存储** V1 = 内存；V2 = 腾讯云 COS（`S3 兼容接口`抽象，云存储 ↔ MinIO 可切换）
- **单位** 全线 cm / cm²（无 mm）
- **设计规范** Apple HIG #00002 / 主色 #0066CC / 字体 Noto Sans SC + Inter / 画板 390×844（iPhone 14）

---

## 6 张表（V1 DemoBackend）

| 表 | 用途 | 关键字段 |
|---|---|---|
| `patient` | 受试者 | `subjectCode`（鉴认代码）/ `displayLabel`（对外显示）/ `protocolId` / `centerId` / `externalPatientId` |
| `wound` | 创面部位 | `patientId` / `bodyPart` / `protocolId` / `centerId` / `deviceId` |
| `assessment` | 单次评估记录 | `patientId` / `woundId` / `finalAreaCm2` / `crfCompletionDeclaredAt` / `concomitantMedications` / `aeRefs` / `photoMetadataSnapshot` |
| `assessment_image` | 创面照片 | `assessmentId` / `cosKey` / `sha256` / `deviceFingerprint` / `exifJson` |
| `audit_log` | 不可撤销审计链 | `opType` / `fieldName` / `beforeValue` / `afterValue` / `reason` / `prevHash` / `currHash`（SHA256 哈希链） |
| `audit_log`（GCP W2） | — | 同上，新增 `sign` 事件类型 + `signOffMethod` |

## W2 新增 5 张 GCP 表

| 表 | 用途 |
|---|---|
| `protocol` | 试验方案（多中心支持） |
| `research_center` | 研究中心（齐鲁、省立 等） |
| `protocol_center_allocation` | 方案-中心 多对多分配 |
| `investigational_device` | 试用器械（model / batch / expiry / centerId） |
| `device_usage_log` | 器械使用台账（allocatedAt / returnedAt / 关联到 patient + assessment） |

---

## 6 角色 RBAC

| 角色 | 权限 |
|---|---|
| `admin` | 系统管理（V1 demo 限定） |
| `pi` | 主要研究者：可签 CRF 完成声明 + 临床字段锁定 |
| `sub_pi` | 副研究者：同 PI 但无 CRF 声明权限 |
| `crc` | 研究协调员：录入 + 修改，无签字段权限 |
| `reviewer` | 监查员 / CRA：只读 + 审计日志查询 |
| `auditor` | 稽查员：只读 + 审计日志完整拉取 |

**真名脱敏**：非 admin / pi 角色只下发 `displayLabel`（如"受试者 #1"或拼音首字母+序号）；真名仅 admin/pi 可见，且走加密映射表。

---

## 核心合规实现

### ALCOA+ 9 项落实位置

| 项 | 实现 |
|---|---|
| **A**ttributable 可归因 | `audit_log.recordId + clinicianId` 每次操作必填 |
| **L**egible 清晰可读 | 评估详情页只读 + 中文字段 |
| **C**ontemporaneous 同时性 | 拍照时间取 EXIF `DateTimeOriginal`；签字段时间取当前 |
| **O**riginal 原始 | 创面照片保留原图 + EXIF + 设备指纹（`photoMetadataSnapshot`） |
| **A**ccurate 准确 | 手工修正轮廓自动计算 cm² + 修正原因写 `audit_log` |
| **C**omplete 完整 | CRF 字段三态校验（ND/UN/NA），缺字段 400 |
| **C**onsistent 一致 | 单位统一 cm/cm²；日期统一 ISO8601 |
| **E**nduring 耐久 | V2 走腾讯云 COS 10 年冷存储 |
| **A**vailable 可用 | 评估详情页"下载原始"按钮可拉 JSON 元数据 |

### GCP §57-63 关键项

- **§57 病例报告表** — Assessment 模型包含全部 CRF 字段
- **§58 原始数据** — 创面照片 `photoMetadataSnapshot` 含 sha256 + COS 路径 + 设备指纹
- **§59 数据更正** — AuditLog `opType=update + before/after + reason` 强制留痕
- **§60 电子签名** — PIN 二次鉴别 + `signOffMethod` 字段 + SIGN_LOCK 锁定临床字段
- **§61 受试者鉴认代码** — `SubjectCodeGenerator` 拼音首字母+4位序号，全大写
- **§62 CRF 完成声明** — `crfCompletionDeclaredAt` + PI 签字段
- **§63 10 年留存** — V2 COS 配置

---

## 项目结构

```
.
├── .gitignore
├── README.md
├── 代码/
│   └── mobile 安卓/                  ← Flutter 3.47.2 项目
│       ├── lib/
│       │   ├── main.dart
│       │   ├── config/                ← app_theme / api_config
│       │   ├── models/                ← 5 + 5 = 10 张表 + enums + request
│       │   ├── services/              ← ApiClient / DemoBackend / AuditLogger /
│       │   │                            SubjectCodeGenerator / COS uploader /
│       │   │                            Trial / Device / Image / Assessment
│       │   ├── providers/             ← AssessmentProvider (ChangeNotifier)
│       │   ├── screens/               ← 12 个页面
│       │   ├── widgets/               ← 通用组件
│       │   └── utils/                 ← photo_time (EXIF) / 等
│       ├── ios/                       ← iOS Runner 配置
│       ├── android/                   ← Android 配置
│       └── pubspec.yaml
├── UI设计/                            ← 6 张设计稿 + README
│   ├── README.md
│   ├── 页面截图/*.png
│   └── 待执行-扫码入口与数据汇总.md
├── 合规规范/                          ← GCP 文档（项目核心交付物）
│   ├── GCP合规要求_老胡参考.md
│   ├── 差距清单与落地建议.md
│   ├── V1开发任务卡.md
│   └── 腾讯云医疗合规申请指南.md
├── 创面评估系统_V1_开发需求规格说明书_修订版.md   ← 规格书正式版
├── 创面评估系统_V1_单位修订说明_cm版.md          ← cm 单位修订说明
└── 创面评估App_小程序需求梳理 - V2.pdf            ← 历史参考（V1 已不沿用）
```

---

## 快速启动

```bash
# 1. 安装依赖
cd "代码/mobile 安卓"
flutter pub get

# 2. 启动 iOS 模拟器
open -a Simulator
xcrun simctl boot "iPhone 16 Pro"

# 3. 构建 + 安装
flutter build ios --simulator --debug
xcrun simctl install booted build/ios/iphonesimulator/Runner.app
xcrun simctl launch booted com.woundassessment.woundAssessment

# 4. Android 真机
flutter devices                              # 查 device id
flutter run -d <device_id>
```

### 演示登录

| 字段 | 值 |
|---|---|
| 手机号 / 工号 | 任意（demo 不校验） |
| 密码 | 任意 |
| 角色 | admin（默认，可看到真名） |

### 4 步走查 V1 完整链路

1. **登录** → 工作台（看到当日待办 + 数据汇总）
2. **患者** → 张伟（受试者鉴认代码 ZW0001）
3. **左小腿** → 看"评估历史"折线图
4. **新建评估** → 拍照（demo 模式自动合成图） → review → NRS/VSS → CRF 三态 → CRF 完成声明（PIN `123456`）→ 签名锁定

---

## 开发任务进度

| 阶段 | 内容 | 状态 |
|---|---|---|
| W0 | 6 张设计稿 + 6 个 Flutter 页面骨架 | ✅ |
| W1 | 鉴认代码 + 审计日志 + 真名脱敏 | ✅ |
| W2 | 试验方案（多中心）+ 器械追溯 | ✅ |
| W3 | 创面照片源数据 + CRF 字段对齐 + CRF 完成声明 | ✅ |
| W4 | eConsent 双通道 + 腾讯云 COS + 6 角色权限 | ⏳ |
| W5 | PDF 导出 + 第三方备份归档 | ⏳ |

详见 [`合规规范/V1开发任务卡.md`](./合规规范/V1开发任务卡.md)。

---

## 贡献者

- **产品 / 设计 / 临床**：[老胡（Blotting Hu）](https://github.com/huyichuan)
- **架构 / 开发**：AI 协作（WorkBuddy + Claude / Gemini 联合）

## 许可证

私有仓库（private），不对外发布。代码属山东研究院临床试验项目组所有。
