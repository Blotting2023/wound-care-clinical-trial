-- 创面评估系统 V1 — 初始临床数据 schema（GCP 医疗器械临床试验）
-- 合规要点：真名不入表（仅鉴认代码 + 病案号）；审计哈希链；留存期；eConsent B 通道
-- 单位：cm / cm²

-- ============ 账号与 RBAC ============
create table if not exists public.users (
  id uuid primary key default gen_random_uuid(),
  username text not null unique,
  display_name text not null default '',
  role text not null check (role in ('PI','SubI','CRC','Sponsor','IRB','Admin')),
  openid text default '',
  center_ids text[] default '{}',
  active boolean not null default true,
  created_at timestamptz not null default now()
);
create index if not exists idx_users_openid on public.users (openid);

-- ============ 受试者（脱敏主表） ============
create table if not exists public.patients (
  id uuid primary key default gen_random_uuid(),
  subject_code text not null unique,          -- 鉴认代码 ZW0001
  mrn text default '',                        -- 病案号（按角色脱敏输出）
  gender text default '',
  birth_year text default '',
  protocol_id text default '',
  center_id text default '',
  consent_status text not null default 'pending',
  enrollment_date timestamptz,
  created_by text default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_patients_center on public.patients (center_id);

-- ============ 创面部位 ============
create table if not exists public.wounds (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references public.patients(id) on delete cascade,
  label text not null default '创面部位',
  body_part text default '',
  created_by text default '',
  created_at timestamptz not null default now()
);
create index if not exists idx_wounds_patient on public.wounds (patient_id);

-- ============ 评估记录 ============
create table if not exists public.assessments (
  id uuid primary key default gen_random_uuid(),
  wound_id uuid not null references public.wounds(id) on delete cascade,
  patient_id uuid not null references public.patients(id) on delete cascade,
  length_cm numeric(8,2) not null default 0,
  width_cm numeric(8,2) not null default 0,
  area_cm2 numeric(10,2) not null default 0,
  tissue_json jsonb default '{}'::jsonb,
  vss_score int,
  crf jsonb default '{}'::jsonb,               -- {medication,disease,ae,visit} 三态 ND/UN/NA
  photo_file_id text default '',
  device_model text default '',
  status text not null default 'pending' check (status in ('pending','locked')),
  created_by text default '',
  created_at timestamptz not null default now(),
  locked_by text default '',
  locked_at timestamptz,
  retention_until date
);
create index if not exists idx_assessments_wound on public.assessments (wound_id);
create index if not exists idx_assessments_patient on public.assessments (patient_id);

-- ============ 知情同意（B 通道：纸质件拍照 + PI 审核） ============
create table if not exists public.consents (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references public.patients(id) on delete cascade,
  mode text not null default 'PAPER_PHOTO' check (mode in ('E_CONSENT','PAPER_PHOTO')),
  status text not null default 'pending_review' check (status in ('pending_review','signed','rejected','withdrawn')),
  photo_file_id text default '',
  signed_date text default '',
  witness_name text default '',
  uploaded_by text default '',
  uploaded_at timestamptz not null default now(),
  reviewed_by text default '',
  reviewed_at timestamptz,
  review_note text default ''
);
create index if not exists idx_consents_patient on public.consents (patient_id);
create index if not exists idx_consents_status on public.consents (status);

-- ============ 研究中心 ============
create table if not exists public.centers (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  department text default '',
  address text default '',
  irb_number text default '',
  lead_pi_name text default '',
  pi_contact text default '',                  -- 负责人联系方式（W6 对齐）
  consent_mode text not null default 'PAPER_PHOTO',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ============ 试验方案 ============
create table if not exists public.protocols (
  id uuid primary key default gen_random_uuid(),
  code text not null,
  name text not null,
  version text default 'v1.0',
  sponsor text default '',
  phase text default '',
  status text not null default 'draft' check (status in ('draft','active','closed')),
  start_date text default '',
  summary text default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.protocol_docs (
  id uuid primary key default gen_random_uuid(),
  protocol_id uuid not null references public.protocols(id) on delete cascade,
  file_name text not null,
  file_ext text default '',
  file_size_bytes bigint default 0,
  version text default 'v1.0',
  uploaded_by text default '',
  uploaded_at timestamptz not null default now()
);
create index if not exists idx_protocol_docs_protocol on public.protocol_docs (protocol_id);

-- ============ 试用器械 ============
create table if not exists public.devices (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  batch_no text default '',
  status text not null default 'in_stock' check (status in ('in_stock','allocated','returned','destroyed')),
  allocated_to text default '',
  created_at timestamptz not null default now()
);

-- ============ GCP 审计哈希链（NMPA §57-63 / ALCOA+） ============
create table if not exists public.audit_logs (
  seq bigserial primary key,
  ts timestamptz not null default now(),
  actor text not null default '',
  role text default '',
  action text not null,
  target text default '',
  detail jsonb default '{}'::jsonb,
  prev_hash text default 'GENESIS',
  hash text not null
);
create index if not exists idx_audit_seq on public.audit_logs (seq desc);

-- ============ 序列号（受试者鉴认代码 ZW0001） ============
create table if not exists public.counters (
  id text primary key,
  seq int not null default 0
);

-- ============ 权限（服务端角色） ============
grant usage on schema public to service_role;
grant all on all tables in schema public to service_role;
grant all on all sequences in schema public to service_role;
grant usage on schema public to authenticated;
grant select, insert, update, delete on all tables in schema public to authenticated;
grant usage, select on all sequences in schema public to authenticated;
