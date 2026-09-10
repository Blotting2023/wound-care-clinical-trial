-- 审计哈希链可复现性修复
--
-- 问题：原 hash 覆盖的是 JS 端 new Date().toISOString()（如 2026-09-10T06:01:24.382Z），
-- 但校验时读的是 timestamptz 回读格式（如 2026-09-10 14:01:24.382+08），字符串不等
-- → 全链校验必然在 seq=1 断裂。
--
-- 修复：新增 ts_iso text 列，保存写入时被哈希的**原始 ISO 字符串**，作为权威时间戳；
-- ts timestamptz 保留，仅用于时间区间查询/排序（不参与哈希）。
--
-- 旧记录因时间格式不可复现，链已不可验证，重置以便从 GENESIS 重建。

alter table public.audit_logs add column if not exists ts_iso text not null default '';

comment on column public.audit_logs.ts_iso is '哈希覆盖的权威时间戳（ISO 8601 原文），ALCOA+ Enduring/Accurate';
comment on column public.audit_logs.ts is '仅用于时间区间查询/排序，不参与哈希';

delete from public.audit_logs;
