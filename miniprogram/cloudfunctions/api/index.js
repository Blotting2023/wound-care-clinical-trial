/**
 * 创面评估系统 V1 — 微信小程序云函数（单函数 action 路由，PostgreSQL 版）
 *
 * 环境：CloudBase PG 模式（wound-gcp-d2gh9r44ta15f1664 / ap-shanghai）
 * 数据通道：@cloudbase/node-sdk app.rdb()（平台网关，无需连接串 / VPC / API Key）
 *
 * 合规特性（与 Flutter 医护端对齐）：
 * - 6 角色 RBAC（W4.6 收紧版）— rbac.js
 * - GCP 审计哈希链 — audit.js（NMPA §57-63 / ALCOA+）
 * - 真名不进主表 + 病案号按角色脱敏（PIPL §6）
 * - 受试者鉴认代码 ZW0001 序列（counters 表）
 * - 数据留存期 = 锁定时间 + 10 年（NMPA §63）
 * - eConsent B 通道：纸质件拍照 + 见证人 + PI 审核
 * - 21 CFR Part 11 简版：PIN 二次鉴别锁定（V2 接 OTP / 生物识别）
 *
 * 单位制：全线 cm / cm²
 */

const cloud = require('wx-server-sdk');
const rbac = require('./rbac');
const { appendAudit, verifyChain } = require('./audit');
const { seed } = require('./seed');
const PG = require('./pg');

cloud.init({ env: cloud.DYNAMIC_CURRENT_ENV });

const RETENTION_YEARS = 10; // NMPA 2022 §63
const PI_DEMO_PIN = '123456'; // V1 demo；上线前必须换 OTP
const ALLOW_DEBUG_AUTH = process.env.ALLOW_DEBUG_AUTH === '1'; // 服务端自测通道，上线前关闭

// ---------- 工具 ----------

function ok(data, extra = {}) {
  return { success: true, data, ...extra };
}

function fail(message, code = 400) {
  return { success: false, message, code };
}

/** 鉴认代码 ZW0001... — counters 读改写（subject_code 唯一约束兜底） */
async function nextSubjectCode() {
  const rows = await PG.selectAll('counters', { filter: { id: 'subject_code' }, limit: 1 });
  if (!rows.length) {
    await PG.insertOne('counters', { id: 'subject_code', seq: 1 });
    return 'ZW0001';
  }
  const next = Number(rows[0].seq) + 1;
  await PG.updateWhere('counters', { id: 'subject_code' }, { seq: next });
  return `ZW${String(next).padStart(4, '0')}`;
}

/** PIPL 数据最小化：仅 PI / SubI / Admin 可见病案号 */
function patientForClient(row, user) {
  const base = PG.PATIENT_OUT(row);
  const see = rbac.canSeeIdentity(user.role);
  return { ...base, mrn: see ? base.mrn : '', mrnMasked: see ? '' : '—' };
}

/** 留存截止日：基准时间 + 10 年 */
function retentionUntil(baseIso) {
  if (!baseIso) return '';
  const d = new Date(baseIso);
  d.setFullYear(d.getFullYear() + RETENTION_YEARS);
  return d.toISOString().slice(0, 10);
}

// ---------- 登录 / 账号 ----------

async function handleLogin(openid, event) {
  await seed();
  const username = (event.username || '').trim();
  if (!username) return fail('请输入工号');

  const existing = await PG.selectOne('users', { username });
  if (!existing) {
    // 工号不存在 → 按前缀派角色自动建号（V1 demo 便捷；V2 改 Admin 手工建号）
    const role = rbac.roleFromUsername(username);
    const nameMap = {
      PI: '研究者', SubI: '副研究者', CRC: '研究协调员',
      Sponsor: '监查员', IRB: '伦理委员', Admin: '管理员',
    };
    const created = await PG.insertOne('users', {
      username, display_name: `${nameMap[role]}（${username}）`,
      role, openid: '', active: true,
    });
    return bindAndReturn(created, openid, username);
  }
  return bindAndReturn(existing, openid, username);
}

async function bindAndReturn(u, openid, username) {
  if (openid) {
    if (u.openid && u.openid !== openid) {
      return fail('该工号已绑定其他微信，请联系管理员', 403);
    }
    if (!u.openid) {
      await PG.updateWhere('users', { id: u.id }, { openid });
      u.openid = openid;
    }
  }
  await appendAudit({
    actor: username, role: u.role, action: 'auth.login', target: u.id,
    detail: { via: 'miniprogram' },
  });
  return ok({
    userId: u.id,
    username: u.username,
    displayName: u.display_name,
    role: u.role,
    roleDisplay: rbac.DISPLAY_NAME[u.role],
    permissions: rbac.permissionsOf(u.role),
  });
}

async function handleGetMe(openid) {
  const u = await PG.selectOne('users', { openid });
  if (!u) return fail('未绑定账号', 401);
  return ok({
    userId: u.id, username: u.username, displayName: u.display_name,
    role: u.role, roleDisplay: rbac.DISPLAY_NAME[u.role],
    permissions: rbac.permissionsOf(u.role),
  });
}

// ---------- 患者 ----------

async function handleCreatePatient(user, body) {
  if (!rbac.can(user, rbac.P.patientCreate)) return fail('无权限：仅研究者可建档', 403);
  const subjectCode = await nextSubjectCode();
  const row = await PG.insertOne('patients', {
    subject_code: subjectCode,
    mrn: (body.mrn || '').trim(),
    gender: body.gender || '',
    birth_year: body.birthYear || '',
    protocol_id: body.protocolId || '',
    center_id: body.centerId || '',
    consent_status: 'pending',
    enrollment_date: new Date().toISOString(),
    created_by: user.username,
  });
  await appendAudit({
    actor: user.username, role: user.role, action: 'patient.create',
    target: row.id, detail: { subjectCode },
  });
  return ok(patientForClient(row, user));
}

async function handleListPatients(user) {
  const rows = await PG.selectAll('patients', {
    order: 'created_at', ascending: false, limit: 100,
  });
  return ok(rows.map((r) => patientForClient(r, user)));
}

async function handleGetPatient(user, event) {
  const row = await PG.selectOne('patients', { id: event.patientId });
  if (!row) return fail('患者不存在', 404);
  const wounds = await PG.selectAll('wounds', {
    filter: { patient_id: event.patientId }, order: 'created_at', ascending: true,
  });
  return ok({ ...patientForClient(row, user), wounds: wounds.map(PG.WOUND_OUT) });
}

// ---------- 创面部位 ----------

async function handleCreateWound(user, body) {
  if (!rbac.can(user, rbac.P.patientCreate)) return fail('无权限：仅研究者可建部位', 403);
  const row = await PG.insertOne('wounds', {
    patient_id: body.patientId,
    label: body.label || '创面部位',
    body_part: body.bodyPart || '',
    created_by: user.username,
  });
  await appendAudit({
    actor: user.username, role: user.role, action: 'wound.create', target: row.id,
    detail: { patientId: body.patientId, label: row.label },
  });
  return ok(PG.WOUND_OUT(row));
}

async function handleListWounds(user, event) {
  const rows = await PG.selectAll('wounds', { filter: { patient_id: event.patientId } });
  return ok(rows.map(PG.WOUND_OUT));
}

// ---------- 评估 ----------

async function handleCreateAssessment(user, body) {
  if (!rbac.can(user, rbac.P.assessmentCreate)) {
    return fail('无权限：创面评估须由研究者本人完成（GCP §4）', 403);
  }
  const l = Number(body.lengthCm || 0);
  const w = Number(body.widthCm || 0);
  const row = await PG.insertOne('assessments', {
    wound_id: body.woundId,
    patient_id: body.patientId,
    length_cm: l,
    width_cm: w,
    area_cm2: Number((l * w).toFixed(2)),
    tissue_json: body.tissueJson || {},
    vss_score: body.vssScore === undefined || body.vssScore === null ? null : Number(body.vssScore),
    crf: body.crf || {},
    photo_file_id: body.photoFileId || '',
    device_model: body.deviceModel || '',
    status: 'pending',
    created_by: user.username,
  });
  await appendAudit({
    actor: user.username, role: user.role, action: 'assessment.create', target: row.id,
    detail: { woundId: row.wound_id, areaCm2: Number(row.area_cm2), vss: row.vss_score },
  });
  return ok(PG.ASSESSMENT_OUT(row));
}

async function handleListAssessments(user, event) {
  const rows = await PG.selectAll('assessments', {
    filter: { wound_id: event.woundId }, order: 'created_at', ascending: false, limit: 50,
  });
  return ok(rows.map(PG.ASSESSMENT_OUT));
}

/** PI 独占锁定签字（21 CFR Part 11 简版：PIN 二次鉴别） */
async function handleLockAssessment(user, event) {
  if (user.role !== 'PI') return fail('锁定签字仅 PI 可执行（21 CFR Part 11）', 403);
  if (event.pin !== PI_DEMO_PIN) {
    await appendAudit({
      actor: user.username, role: user.role, action: 'auth.pinFailed',
      target: event.assessmentId, detail: {},
    });
    return fail('PIN 错误', 401);
  }
  const doc = await PG.selectOne('assessments', { id: event.assessmentId });
  if (!doc) return fail('评估不存在', 404);
  if (doc.status === 'locked') return fail('已锁定');

  const now = new Date().toISOString();
  const until = retentionUntil(now);
  await PG.updateWhere('assessments', { id: event.assessmentId }, {
    status: 'locked', locked_by: user.username, locked_at: now, retention_until: until,
  });
  await appendAudit({
    actor: user.username, role: user.role, action: 'assessment.lock',
    target: event.assessmentId,
    detail: { signatureMeaning: 'PI 确认本次评估记录准确完整（21 CFR Part 11 §11.50）' },
  });
  return ok({ lockedAt: now, retentionUntil: until });
}

// ---------- eConsent（B 通道：纸质件拍照 + PI 审核） ----------

async function handleUploadConsent(user, body) {
  if (!rbac.can(user, rbac.P.patientUpdateBasic)) return fail('无权限', 403);
  const row = await PG.insertOne('consents', {
    patient_id: body.patientId,
    mode: 'PAPER_PHOTO',
    status: 'pending_review',
    photo_file_id: body.photoFileId || '',
    signed_date: body.signedDate || '',
    witness_name: body.witnessName || '',
    uploaded_by: user.username,
  });
  await appendAudit({
    actor: user.username, role: user.role, action: 'consent.upload', target: row.id,
    detail: { patientId: body.patientId },
  });
  return ok(PG.CONSENT_OUT(row));
}

async function handleListConsents(user, event) {
  const filter = event && event.status ? { status: event.status } : {};
  const rows = await PG.selectAll('consents', {
    filter, order: 'uploaded_at', ascending: false, limit: 50,
  });
  return ok(rows.map(PG.CONSENT_OUT));
}

async function handleReviewConsent(user, event) {
  if (user.role !== 'PI') return fail('知情审核仅 PI 可执行（GCP §6）', 403);
  const now = new Date().toISOString();
  const status = event.approve ? 'signed' : 'rejected';
  const c = await PG.selectOne('consents', { id: event.consentId });
  if (!c) return fail('知情记录不存在', 404);
  await PG.updateWhere('consents', { id: event.consentId }, {
    status, reviewed_by: user.username, reviewed_at: now, review_note: event.note || '',
  });
  if (event.approve) {
    await PG.updateWhere('patients', { id: c.patient_id }, { consent_status: 'signed' });
  }
  await appendAudit({
    actor: user.username, role: user.role,
    action: event.approve ? 'consent.approve' : 'consent.reject',
    target: event.consentId, detail: { note: event.note || '' },
  });
  return ok({ status });
}

// ---------- 试验管理 ----------

async function handleListCenters() {
  const rows = await PG.selectAll('centers', { order: 'code', ascending: true });
  return ok(rows.map(PG.CENTER_OUT));
}

async function handleUpdateCenter(user, event) {
  if (!rbac.can(user, rbac.P.centerManage)) return fail('无权限：仅 PI/Admin 可编辑中心', 403);
  await PG.updateWhere('centers', { id: event.centerId }, {
    lead_pi_name: event.leadPiName || '',
    pi_contact: event.piContact || '',
    updated_at: new Date().toISOString(),
  });
  await appendAudit({
    actor: user.username, role: user.role, action: 'center.update', target: event.centerId,
    detail: { leadPiName: event.leadPiName, piContact: event.piContact },
  });
  return ok({});
}

async function handleListProtocols() {
  const rows = await PG.selectAll('protocols', { order: 'created_at', ascending: false });
  return ok(rows.map(PG.PROTOCOL_OUT));
}

async function handleListProtocolDocs(event) {
  const rows = await PG.selectAll('protocol_docs', {
    filter: { protocol_id: event.protocolId }, order: 'uploaded_at', ascending: false,
  });
  return ok(rows.map(PG.PROTOCOL_DOC_OUT));
}

async function handleUploadProtocolDoc(user, body) {
  if (!rbac.can(user, rbac.P.protocolManage)) {
    return fail('无权限：仅 PI/Admin 可上传方案文档', 403);
  }
  const row = await PG.insertOne('protocol_docs', {
    protocol_id: body.protocolId,
    file_name: body.fileName,
    file_ext: body.fileExt || '',
    file_size_bytes: Number(body.fileSizeBytes || 0),
    version: body.version || 'v1.0',
    uploaded_by: user.username,
  });
  await appendAudit({
    actor: user.username, role: user.role, action: 'protocol_document.create',
    target: row.id, detail: { fileName: row.file_name },
  });
  return ok(PG.PROTOCOL_DOC_OUT(row));
}

async function handleListDevices() {
  const rows = await PG.selectAll('devices');
  return ok(rows.map(PG.DEVICE_OUT));
}

// ---------- 工作台聚合（按角色分流） ----------

async function handleDashboard(user) {
  const subjects = await PG.count('patients');

  if (user.role === 'Sponsor') {
    // GCP §5：申办者仅聚合统计，不见个体数据
    const locked = await PG.count('assessments', { status: 'locked' });
    const total = await PG.count('assessments');
    return ok({
      view: 'sponsor',
      stats: { subjects, lockedAssessments: locked, ongoing: total - locked },
    });
  }

  if (user.role === 'IRB') {
    // GCP §6：伦理委员会只见伦理相关材料（受试者以鉴认代码呈现）
    const pend = await PG.selectAll('consents', {
      filter: { status: 'pending_review' }, order: 'uploaded_at', ascending: false, limit: 50,
    });
    const out = [];
    for (const c of pend) {
      const p = await PG.selectOne('patients', { id: c.patient_id });
      out.push({
        _id: c.id,
        subjectCode: p ? p.subject_code : '—',
        uploadedAt: c.uploaded_at,
        uploadedBy: c.uploaded_by,
        signedDate: c.signed_date,
        witnessName: c.witness_name,
      });
    }
    return ok({ view: 'irb', pendingConsents: out });
  }

  if (user.role === 'Admin') {
    const centers = await PG.count('centers');
    const users = await PG.count('users');
    return ok({ view: 'admin', stats: { subjects, centers, users } });
  }

  // 临床视图（PI / SubI / CRC）
  const asm = await PG.selectAll('assessments', {
    order: 'created_at', ascending: false, limit: 10,
  });
  const recent = [];
  for (const a of asm) {
    const w = await PG.selectOne('wounds', { id: a.wound_id });
    const p = await PG.selectOne('patients', { id: a.patient_id });
    recent.push({
      ...PG.ASSESSMENT_OUT(a),
      woundLabel: w ? w.label : '',
      subjectCode: p ? p.subject_code : '',
    });
  }
  const pendingSign = recent.filter((a) => a.status === 'pending').length;
  return ok({
    view: 'clinical',
    stats: { subjects, pendingSign, total: recent.length },
    recent,
    retentionUntil: recent.length ? retentionUntil(recent[0].createdAt) : '',
  });
}

// ---------- 审计 ----------

async function handleAuditLog(user) {
  if (!rbac.can(user, rbac.P.auditRead)) return fail('无权限', 403);
  const rows = await PG.selectAll('audit_logs', { order: 'seq', ascending: false, limit: 100 });
  return ok({
    logs: rows.map((r) => ({
      seq: r.seq, ts: r.ts_iso || r.ts, actor: r.actor, role: r.role, action: r.action,
      target: r.target, detail: r.detail, hash: r.hash, prevHash: r.prev_hash,
    })),
  });
}

async function handleAuditVerify(user) {
  if (!rbac.can(user, rbac.P.auditRead)) return fail('无权限', 403);
  return ok(await verifyChain());
}

// ---------- 主入口 ----------

exports.main = async (event) => {
  const wxContext = cloud.getWXContext();
  let openid = wxContext.OPENID || '';
  const action = event.action;

  // 服务端自测通道：非小程序调用（openid 为空）且显式开启时才允许用工号直连
  if (!openid && ALLOW_DEBUG_AUTH && event.__debugUser) {
    openid = `debug:${event.__debugUser}`;
  }

  try {
    if (action === 'ping') return ok({ pong: true, ts: Date.now() });

    // 诊断用：探测 PG 通道连通性（仅自测开关打开时可用，上线前关闭）
    if (action === 'pgprobe') {
      if (!ALLOW_DEBUG_AUTH) return fail('未开放', 403);
      const raw = await PG.pg.from('users').select('id').limit(1);
      return ok({
        status: raw && raw.status,
        ok: !(raw && raw.error),
        error: (raw && raw.error && raw.error.message) || null,
        rowCount: (raw && raw.data && raw.data.length) || 0,
        envName: process.env.TCB_ENV || process.env.SCF_NAMESPACE || '',
        nodeSdkVersion: require('@cloudbase/node-sdk/package.json').version,
      });
    }

    if (action === 'login') return await handleLogin(openid, event);

    // 其余 action：确保种子就绪（幂等）
    await seed();

    const u = await PG.selectOne('users', { openid });
    if (!u) return fail('未绑定账号，请先登录', 401);
    const user = { id: u.id, username: u.username, role: u.role, displayName: u.display_name };

    switch (action) {
      case 'getMe': return await handleGetMe(openid);
      case 'dashboard': return await handleDashboard(user);
      case 'createPatient': return await handleCreatePatient(user, event);
      case 'listPatients': return await handleListPatients(user);
      case 'getPatient': return await handleGetPatient(user, event);
      case 'createWound': return await handleCreateWound(user, event);
      case 'listWounds': return await handleListWounds(user, event);
      case 'createAssessment': return await handleCreateAssessment(user, event);
      case 'listAssessments': return await handleListAssessments(user, event);
      case 'lockAssessment': return await handleLockAssessment(user, event);
      case 'uploadConsent': return await handleUploadConsent(user, event);
      case 'listConsents': return await handleListConsents(user, event);
      case 'reviewConsent': return await handleReviewConsent(user, event);
      case 'listCenters': return await handleListCenters();
      case 'updateCenter': return await handleUpdateCenter(user, event);
      case 'listProtocols': return await handleListProtocols();
      case 'listProtocolDocs': return await handleListProtocolDocs(event);
      case 'uploadProtocolDoc': return await handleUploadProtocolDoc(user, event);
      case 'listDevices': return await handleListDevices();
      case 'auditLog': return await handleAuditLog(user);
      case 'auditVerify': return await handleAuditVerify(user);
      default: return fail(`未知 action: ${action}`, 404);
    }
  } catch (e) {
    console.error('[api error]', action, e && e.message, e && e.stack);
    return fail(`服务异常：${e.message}`, 500);
  }
};
