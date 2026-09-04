# 创面评估系统 V1 规格书单位修订说明（cm 版）

> 修订编号：V1.1
> 修订日期：2026-08-28
> 修订依据：与项目负责人（老胡）确认——**全系统统一使用厘米（cm / cm²）**，废弃毫米（mm / mm²）作为业务计量单位。
> 基线文档：《创面评估系统_V1_开发需求规格说明书_修订版.md》
> 修订方式：本说明作为增量变更记录单独留存，基线文档不直接改写，保证可追溯（审计友好）。

---

## 1. 修订动机

原规格书中创面测量同时出现 mm 与 cm 两种单位（校准卡用 cm、AI/数据库字段用 mm），且移动端模型曾使用 cm 字段，造成契约不一致。为统一度量、避免换算歧义（1 cm = 10 mm），全线改为厘米。

## 2. 术语变更

| 原术语 | 修订后 | 说明 |
| --- | --- | --- |
| area_mm2 | area_cm2 | 面积，单位 cm² |
| length_mm | length_cm | 长径，单位 cm |
| width_mm | width_cm | 宽径，单位 cm |
| scale_factor_mm_per_pixel | scale_factor_cm_per_pixel | 像素-物理长度比例，单位 cm/pixel |

## 3. 数据库列变更（assessment 表）

| 原列名 | 修订后列名 | 类型 |
| --- | --- | --- |
| scale_factor_mm_per_pixel | scale_factor_cm_per_pixel | numeric(12,8)，> 0 |
| ai_area_mm2 | ai_area_cm2 | numeric(12,2) nullable |
| ai_length_mm | ai_length_cm | numeric(12,2) nullable |
| ai_width_mm | ai_width_cm | numeric(12,2) nullable |
| final_area_mm2 | final_area_cm2 | numeric(12,2) nullable |
| final_length_mm | final_length_cm | numeric(12,2) nullable |
| final_width_mm | final_width_cm | numeric(12,2) nullable |

约束同步更新：

- `final_area_cm2` 在 LOCKED 状态必须非空。
- `scale_factor_cm_per_pixel` 必须大于 0。

> 注：`ai_depth_mm` 未在基线中出现；若后续增加深度字段，一律使用 `*_depth_cm`。移动端模型已按 cm 实现（`aiDepthCm` / `tunnelDepthCm`）。

## 4. AI 服务契约变更（CV 服务返回格式）

`POST /assessments/{id}/analyze` 返回 JSON 中：

| 原字段 | 修订后字段 |
| --- | --- |
| area_mm2 | area_cm2 |
| length_mm | length_cm |
| width_mm | width_cm |

- `wound_polygon` / `tissue_polygons` 坐标单位仍为**像素**（以脱敏后上传图像为参考系），不随单位制变更。
- `tissue_percentages`（组织占比百分比）无单位，不受影响。
- AI 服务内部可仍以 mm 计算，但**对外契约必须输出 cm**；换算由 AI 服务侧负责，App 与数据库不承担换算。

## 5. 校准卡（5.4 节）变更

| 原文 | 修订后 |
| --- | --- |
| 二维码内容格式 `CALCARD:{card_id}:{version}:{size_mm}` | `CALCARD:{card_id}:{version}:{size_cm}` |
| V1 size_mm 固定为 50 | V1 size_cm 固定为 5（卡片物理尺寸 5cm x 5cm） |

- 校准卡物理尺寸不变（5cm x 5cm，即 50mm x 50mm），仅二维码载荷单位改为 cm。
- 识别定位点后计算 `scale_factor_cm_per_pixel`。
- 兼容性说明：V1 阶段校准卡与 App 同版本发布，不要求解析旧 mm 载荷；若需兼容旧卡，App 可对 `size_mm` 载荷除以 10 后按 cm 处理（实现细节，非契约）。

## 6. 保持不变的部分

- 像素坐标：多边形点 `[{ "x": 123.4, "y": 567.8 }]` 仍为像素。
- 图像尺寸：`image_width_px` / `image_height_px` 仍为像素。
- 组织占比：`tissue_percentages` 仍为百分比数值。
- 时间、状态、签名、审计等字段不受影响。

## 7. 影响范围与迁移

1. **移动端（Flutter）**：已完成，模型与界面统一使用 cm / cm²（`aiAreaCm2`、`finalAreaCm2` 等）。
2. **后端（Spring Boot）**：建表脚本与 DTO 字段按上表命名；Flyway 初始版本即按 cm 建表，无需数据迁移（尚未上线）。
3. **Web 管理端（Vue3）**：展示与录入字段按 cm 实现。
4. **AI 服务**：对外契约输出 cm；多边形像素坐标不变。

## 8. 待办

- [x] 移动端模型/界面 cm 化
- [x] 本修订说明
- [ ] 后端 DDL / DTO 按 cm 落地（后端启动时执行）
- [ ] AI 服务契约文档同步（AI 引擎规划时执行）
