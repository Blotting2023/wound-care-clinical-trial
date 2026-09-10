/**
 * CloudBase PostgreSQL 数据访问层
 *
 * 通道：@cloudbase/node-sdk 的 app.rdb()（PostgREST 风格），
 * 走平台网关 + 环境内临时凭据，无需连接串 / VPC / API Key。
 *
 * 命名约定：
 * - 物理表列 snake_case（PG 惯例）
 * - 对外输出 camelCase（保持小程序端既有契约不变）
 */

const cloudbase = require('@cloudbase/node-sdk');

const app = cloudbase.init({ env: cloudbase.SYMBOL_CURRENT_ENV });

// 注意：rdb() 默认把 schema 设为 envId（Accept-Profile），而业务表在 public schema，
// 必须显式指定，否则 PostgREST 返回 406 DATABASE_PGRST106 Invalid schema。
const pg = app.rdb({ database: 'public' });

/** 统一的 postgREST 调用包装：{data, error} → data / throw */
async function run(builder) {
  const res = await builder;
  if (res && res.error) {
    const err = res.error;
    const msg =
      err.message || err.details || err.hint || err.code || safeJson(err);
    console.error('[pg] error detail:', safeJson(err), 'status:', res.status, res.statusText);
    throw new Error(`PG_ERROR: ${msg}`);
  }
  return res ? res.data : null;
}

function safeJson(v) {
  try {
    return JSON.stringify(v);
  } catch (e) {
    return String(v);
  }
}

// ---------- 基础操作 ----------

async function selectAll(table, { filter = {}, order, ascending = false, limit = 100 } = {}) {
  let q = pg.from(table).select('*');
  for (const [k, v] of Object.entries(filter)) {
    q = v === null ? q.is(k, null) : q.eq(k, v);
  }
  if (order) q = q.order(order, { ascending });
  if (limit) q = q.limit(limit);
  return (await run(q)) || [];
}

async function selectOne(table, filter) {
  const rows = await selectAll(table, { filter, limit: 1 });
  return rows[0] || null;
}

async function insertOne(table, row) {
  const rows = await run(pg.from(table).insert(row).select());
  return rows && rows[0] ? rows[0] : null;
}

async function updateWhere(table, filter, patch) {
  let q = pg.from(table).update(patch);
  for (const [k, v] of Object.entries(filter)) q = q.eq(k, v);
  const rows = await run(q.select());
  return rows || [];
}

async function count(table, filter = {}) {
  let q = pg.from(table).select('*', { count: 'exact', head: true });
  for (const [k, v] of Object.entries(filter)) q = q.eq(k, v);
  const res = await q;
  if (res && res.error) {
    console.error('[pg] count error:', safeJson(res.error));
    throw new Error(`PG_ERROR: ${res.error.message || safeJson(res.error)}`);
  }
  return res && typeof res.count === 'number' ? res.count : 0;
}

// ---------- 字段映射（snake_case ↔ camelCase） ----------

const PATIENT_OUT = (r) => ({
  _id: r.id,
  subjectCode: r.subject_code,
  mrn: r.mrn || '',
  gender: r.gender || '',
  birthYear: r.birth_year || '',
  protocolId: r.protocol_id || '',
  centerId: r.center_id || '',
  consentStatus: r.consent_status || 'pending',
  enrollmentDate: r.enrollment_date || '',
  createdAt: r.created_at,
});

const WOUND_OUT = (r) => ({
  _id: r.id,
  patientId: r.patient_id,
  label: r.label,
  bodyPart: r.body_part || '',
  createdAt: r.created_at,
  createdBy: r.created_by || '',
});

const ASSESSMENT_OUT = (r) => ({
  _id: r.id,
  woundId: r.wound_id,
  patientId: r.patient_id,
  lengthCm: Number(r.length_cm || 0),
  widthCm: Number(r.width_cm || 0),
  areaCm2: Number(r.area_cm2 || 0),
  tissueJson: r.tissue_json || {},
  vssScore: r.vss_score === null || r.vss_score === undefined ? null : r.vss_score,
  crf: r.crf || {},
  photoFileId: r.photo_file_id || '',
  deviceModel: r.device_model || '',
  status: r.status || 'pending',
  createdBy: r.created_by || '',
  createdAt: r.created_at,
  lockedBy: r.locked_by || '',
  lockedAt: r.locked_at || '',
  retentionUntil: r.retention_until || '',
});

const CONSENT_OUT = (r) => ({
  _id: r.id,
  patientId: r.patient_id,
  mode: r.mode,
  status: r.status,
  photoFileId: r.photo_file_id || '',
  signedDate: r.signed_date || '',
  witnessName: r.witness_name || '',
  uploadedBy: r.uploaded_by || '',
  uploadedAt: r.uploaded_at,
  reviewedBy: r.reviewed_by || '',
  reviewedAt: r.reviewed_at || '',
  reviewNote: r.review_note || '',
});

const CENTER_OUT = (r) => ({
  _id: r.id,
  code: r.code,
  name: r.name,
  department: r.department || '',
  address: r.address || '',
  irbNumber: r.irb_number || '',
  leadPiName: r.lead_pi_name || '',
  piContact: r.pi_contact || '',
  consentMode: r.consent_mode || 'PAPER_PHOTO',
  createdAt: r.created_at,
  updatedAt: r.updated_at,
});

const PROTOCOL_OUT = (r) => ({
  _id: r.id,
  code: r.code,
  name: r.name,
  version: r.version || 'v1.0',
  sponsor: r.sponsor || '',
  phase: r.phase || '',
  status: r.status || 'draft',
  startDate: r.start_date || '',
  summary: r.summary || '',
  createdAt: r.created_at,
  updatedAt: r.updated_at,
});

const PROTOCOL_DOC_OUT = (r) => ({
  _id: r.id,
  protocolId: r.protocol_id,
  fileName: r.file_name,
  fileExt: r.file_ext || '',
  fileSizeBytes: Number(r.file_size_bytes || 0),
  version: r.version || 'v1.0',
  uploadedBy: r.uploaded_by || '',
  uploadedAt: r.uploaded_at,
});

const DEVICE_OUT = (r) => ({
  _id: r.id,
  code: r.code,
  name: r.name,
  batchNo: r.batch_no || '',
  status: r.status || 'in_stock',
  allocatedTo: r.allocated_to || '',
  createdAt: r.created_at,
});

const USER_OUT = (r) => ({
  userId: r.id,
  username: r.username,
  displayName: r.display_name || '',
  role: r.role,
  openid: r.openid || '',
  active: r.active !== false,
});

module.exports = {
  app,
  pg,
  run,
  selectAll,
  selectOne,
  insertOne,
  updateWhere,
  count,
  PATIENT_OUT,
  WOUND_OUT,
  ASSESSMENT_OUT,
  CONSENT_OUT,
  CENTER_OUT,
  PROTOCOL_OUT,
  PROTOCOL_DOC_OUT,
  DEVICE_OUT,
  USER_OUT,
};
