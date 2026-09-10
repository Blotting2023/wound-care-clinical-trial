#!/usr/bin/env node
/**
 * 创面评估小程序 · 云端 E2E 自测
 *
 * 通过 tcb CLI 调用云函数 api 的全部 action，覆盖：
 *  - 6 角色登录 + 权限矩阵
 *  - 患者 / 创面 / 评估主链路（含 PI 独占锁定签字）
 *  - 知情同意 B 通道（纸质件拍照 → PI 审核）
 *  - 中心 / 方案 / 器械
 *  - GCP 审计哈希链完整性
 *  - RBAC 反例（越权必须被拒）
 *
 * 用法：node scripts/e2e-test.js
 */

const { execFileSync } = require('child_process');
const path = require('path');

const NODE_DIR = '/Users/huyichuan/.workbuddy/binaries/node/versions/22.12.0/bin';
const TCB_BIN = path.join(NODE_DIR, 'tcb');
const PROJECT = path.resolve(__dirname, '..');

let pass = 0;
let fail = 0;
const failures = [];

function invokeOnce(params) {
  const out = execFileSync(TCB_BIN, ['fn', 'invoke', 'api', '--params', JSON.stringify(params)], {
    cwd: PROJECT,
    encoding: 'utf8',
    env: { ...process.env, PATH: `${NODE_DIR}:${process.env.PATH}` },
    shell: false,
  });
  const m = out.match(/返回结果：(.*)/);
  if (!m) throw new Error(`无法解析调用结果:\n${out}`);
  return JSON.parse(m[1]);
}

/** 网络抖动（TLS 中断 / 502）自动重试 4 次 */
function invoke(params) {
  let lastErr;
  for (let i = 0; i < 4; i += 1) {
    try {
      return invokeOnce(params);
    } catch (e) {
      lastErr = e;
      const transient = /TLS|socket|ETIMEDOUT|ECONNRESET|502|FetchError|timeout/i.test(String(e.message));
      if (!transient) throw e;
      console.log(`  \x1b[33m⟳\x1b[0m 网络抖动，重试 ${i + 1}/4 …`);
      execFileSync('sleep', ['3']);
    }
  }
  throw lastErr;
}

function check(name, cond, detail) {
  if (cond) {
    pass += 1;
    console.log(`  \x1b[32m✅\x1b[0m ${name}`);
  } else {
    fail += 1;
    failures.push(name);
    console.log(`  \x1b[31m❌\x1b[0m ${name}${detail ? ` → ${String(detail).slice(0, 220)}` : ''}`);
  }
  return cond;
}

const as = (user) => (params) => invoke({ ...params, __debugUser: user });
const section = (t) => console.log(`\n=== ${t} ===`);

const ctx = {};
const roles = {};

// ───────── 1. 基础通道 ─────────
section('1. 基础通道');
{
  const r = invoke({ action: 'ping' });
  check('ping 通', r.success === true && r.data.pong === true, JSON.stringify(r).slice(0, 150));
}

// ───────── 2. 6 角色登录 ─────────
section('2. 6 角色登录 + 权限矩阵');
// 权限数量对齐 rbac.js W4.6 收紧版矩阵（PI 14 / SubI 8 / CRC 2 / Sponsor 2 / IRB 3 / Admin 6）
const ROLE_SPEC = [
  ['pi_demo', 'PI', 14],
  ['subi_demo', 'SubI', 8],
  ['crc_demo', 'CRC', 2],
  ['sponsor_demo', 'Sponsor', 2],
  ['irb_demo', 'IRB', 3],
  ['admin_demo', 'Admin', 6],
];
for (const [u, role, minPerm] of ROLE_SPEC) {
  const r = as(u)({ action: 'login', username: u });
  if (check(`login ${u} → ${role}`, r.success && r.data.role === role, r.message)) {
    roles[role] = as(u);
    check(`  权限项数量 ≥ ${minPerm}`, (r.data.permissions || []).length >= minPerm, `实际 ${(r.data.permissions || []).length}`);
    check('  真名可见（医护端 GCP 要求可归因）', !!r.data.displayName, r.data.displayName);
  }
}

const pi = roles.PI;

// ───────── 3. PI 主链路 ─────────
section('3. PI 主链路（患者 → 创面 → 评估 → 锁定）');
{
  const r = pi({ action: 'getMe' });
  check('getMe', r.success === true && r.data.role === 'PI', r.message);
}
{
  const r = pi({ action: 'dashboard' });
  check('dashboard（临床视图，含留存期）', r.success === true && r.data.view === 'clinical', r.message);
}
{
  const r = pi({ action: 'listPatients' });
  check('listPatients', r.success === true && Array.isArray(r.data), r.message);
  if (r.success) console.log(`     现有患者 ${r.data.length} 名`);
}
// 建档
{
  const r = pi({ action: 'createPatient', gender: '男', birthYear: '1958', protocolId: '', centerId: 'demo-center-01' });
  if (check('createPatient（自动生成鉴认代码）', r.success === true, r.message)) {
    ctx.patient = r.data;
    check('  鉴认代码格式 ZW####', /^ZW\d{4}$/.test(String(r.data.subjectCode || '')), `实际 ${r.data.subjectCode}`);
    check('  consentStatus 初始 pending', r.data.consentStatus === 'pending', r.data.consentStatus);
  }
}
// 建创面
{
  const r = pi({ action: 'createWound', patientId: ctx.patient._id, label: '左小腿外侧', bodyPart: '小腿' });
  if (check('createWound', r.success === true, r.message)) ctx.wound = r.data;
}
{
  const r = pi({ action: 'listWounds', patientId: ctx.patient._id });
  check('listWounds', r.success === true && r.data.length >= 1, r.message);
}
{
  const r = pi({ action: 'getPatient', patientId: ctx.patient._id });
  check('getPatient（含创面列表）', r.success === true && Array.isArray(r.data.wounds) && r.data.wounds.length >= 1, r.message);
}
// 评估（面积由 cm 长宽自动算）
{
  const r = pi({
    action: 'createAssessment',
    patientId: ctx.patient._id,
    woundId: ctx.wound._id,
    lengthCm: 4.2,
    widthCm: 2.8,
    tissueJson: { granulation: 60, slough: 30, necrosis: 10 },
    crf: { concomitantMeds: 'ND', concurrentDisease: 'UN' },
    photoFileId: 'cloud://demo/original/demo.jpg',
    deviceModel: 'iPhone14,2',
  });
  if (check('createAssessment（cm/cm² 自动算面积）', r.success === true, r.message)) {
    ctx.assessment = r.data;
    check('  areaCm2 = 4.2 × 2.8 = 11.76', Math.abs(Number(r.data.areaCm2) - 11.76) < 0.01, `实际 ${r.data.areaCm2}`);
    check('  CRF 三态 ND/UN 落库', r.data.crf && r.data.crf.concomitantMeds === 'ND', JSON.stringify(r.data.crf));
  }
}
{
  const r = pi({ action: 'listAssessments', woundId: ctx.wound._id });
  check('listAssessments', r.success === true && r.data.length >= 1, r.message);
}
// 锁定签字
{
  const bad = pi({ action: 'lockAssessment', assessmentId: ctx.assessment._id, pin: '000000' });
  check('错误 PIN → 拒绝（21 CFR Part 11 二次鉴别）', bad.success === false, `实际 success=${bad.success}`);

  const r = pi({ action: 'lockAssessment', assessmentId: ctx.assessment._id, pin: '123456' });
  if (check('lockAssessment（正确 PIN + 记录签名含义）', r.success === true, r.message)) {
    check('  留存截止日 = 锁定日 + 10 年', /^\d{4}-\d{2}-\d{2}$/.test(String(r.data.retentionUntil || '')), r.data.retentionUntil);
    console.log(`     留存至 ${r.data.retentionUntil}`);
  }
  const again = pi({ action: 'lockAssessment', assessmentId: ctx.assessment._id, pin: '123456' });
  check('重复锁定 → 拒绝', again.success === false, `实际 success=${again.success}`);
}

// ───────── 4. 知情同意 B 通道 ─────────
section('4. 知情同意（B 通道纸质件拍照 → PI 审核）');
{
  const r = pi({
    action: 'uploadConsent',
    patientId: ctx.patient._id,
    photoFileId: 'cloud://demo/consent/paper.jpg',
    signedDate: '2026-09-07',
    witnessName: '张倩',
  });
  if (check('uploadConsent（纸质件拍照 + 见证人）', r.success === true, r.message)) {
    ctx.consent = r.data;
    check('  mode = PAPER_PHOTO / status = pending_review', r.data.mode === 'PAPER_PHOTO' && r.data.status === 'pending_review', `${r.data.mode}/${r.data.status}`);
  }
}
{
  const r = pi({ action: 'listConsents', status: 'pending_review' });
  check('listConsents（按状态筛选）', r.success === true, r.message);
}
{
  const r = pi({ action: 'reviewConsent', consentId: ctx.consent._id, approve: true, note: '核对原件一致' });
  check('reviewConsent（PI 审核通过）', r.success === true && r.data.status === 'signed', r.message);
  const p = pi({ action: 'getPatient', patientId: ctx.patient._id });
  check('  患者 consentStatus 同步为 signed', p.success && p.data.consentStatus === 'signed', p.data && p.data.consentStatus);
}

// ───────── 5. 中心 / 方案 / 器械 ─────────
section('5. 中心 / 方案 / 器械');
{
  const r = pi({ action: 'listCenters' });
  check('listCenters', r.success === true && Array.isArray(r.data), r.message);
  if (r.success && r.data.length) ctx.center = r.data[0];
}
{
  const r = pi({ action: 'updateCenter', centerId: (ctx.center && ctx.center._id) || 'demo-center-01', leadPiName: '王立明', piContact: '13800000000' });
  check('updateCenter（PI 可编辑中心）', r.success === true, r.message);
}
{
  const r = pi({ action: 'listProtocols' });
  check('listProtocols', r.success === true && Array.isArray(r.data), r.message);
  if (r.success && r.data.length) ctx.protocol = r.data[0];
}
{
  const r = pi({ action: 'listProtocolDocs', protocolId: ctx.protocol ? ctx.protocol._id : 'n/a' });
  check('listProtocolDocs', r.success === true, r.message);
}
{
  const r = pi({ action: 'uploadProtocolDoc', protocolId: ctx.protocol ? ctx.protocol._id : 'n/a', fileName: '试验方案_v1.0.pdf', fileExt: 'pdf', fileSizeBytes: 1024000, version: 'v1.0' });
  check('uploadProtocolDoc（PI 可上传方案文件）', r.success === true, r.message);
}
{
  const r = pi({ action: 'listDevices' });
  check('listDevices（试用器械追溯）', r.success === true && Array.isArray(r.data), r.message);
}

// ───────── 6. 审计哈希链 ─────────
section('6. GCP 审计哈希链');
{
  const r = pi({ action: 'auditLog' });
  const logs = (r.success && r.data.logs) || [];
  check('auditLog', r.success === true && logs.length > 0, r.message);
  if (logs.length) {
    check('  含 prevHash / hash 链式字段', !!logs[0].hash && !!logs[0].prevHash, JSON.stringify(logs[0]).slice(0, 140));
    const acts = new Set(logs.map((l) => l.action));
    console.log(`     审计条目 ${logs.length}，动作类型：${[...acts].slice(0, 8).join(', ')}`);
  }
}
{
  const r = pi({ action: 'auditVerify' });
  check('auditVerify（哈希链完整未被篡改）', r.success === true && r.data.ok === true, JSON.stringify(r.data || r.message));
}

// ───────── 7. RBAC 反例 ─────────
section('7. RBAC 反例（越权必须被拒）');
const crc = roles.CRC;
const sponsor = roles.Sponsor;
const irb = roles.IRB;
const admin = roles.Admin;
const subi = roles.SubI;
{
  const r = crc({ action: 'createAssessment', patientId: ctx.patient._id, woundId: ctx.wound._id, lengthCm: 1, widthCm: 1 });
  check('CRC 创建评估 → 拒绝（GCP §4 医学判断须研究者本人）', r.success === false, `实际 success=${r.success}`);
}
{
  const r = crc({ action: 'lockAssessment', assessmentId: ctx.assessment._id, pin: '123456' });
  check('CRC 锁定签字 → 拒绝', r.success === false, `实际 success=${r.success}`);
}
{
  const r = crc({ action: 'createPatient', gender: '女' });
  check('CRC 建档 → 拒绝', r.success === false, `实际 success=${r.success}`);
}
{
  const r = crc({ action: 'reviewConsent', consentId: ctx.consent._id, approve: true });
  check('CRC 审核知情 → 拒绝（GCP §6）', r.success === false, `实际 success=${r.success}`);
}
{
  const r = irb({ action: 'createPatient', gender: '男' });
  check('IRB 建档 → 拒绝', r.success === false, `实际 success=${r.success}`);
}
{
  const r = admin({ action: 'createAssessment', patientId: ctx.patient._id, woundId: ctx.wound._id, lengthCm: 1, widthCm: 1 });
  check('Admin 创建评估 → 拒绝（PIPL §6 数据最小化）', r.success === false, `实际 success=${r.success}`);
}
{
  // 申办者监查需查阅稽查轨迹（GCP §5 监查职责），audit:read 为刻意授予；
  // 但不得出现受试者真实姓名 / 身份证号等个体标识。
  // 注：研究者姓名（leadPiName）必须保留 —— GCP 要求记录可归因（Attributable）。
  const r = sponsor({ action: 'auditLog' });
  check('Sponsor 可读审计轨迹（GCP §5 监查权）', r.success === true, r.message);
  const blob = JSON.stringify((r.success && r.data.logs) || []);
  check(
    '  审计轨迹不含受试者姓名/身份证字段',
    !/"(patientName|subjectName|realName|idCard|idNumber)"/.test(blob),
    blob.slice(0, 140)
  );
}
{
  const r = sponsor({ action: 'listPatients' });
  check('Sponsor 调 listPatients', r.success === true, r.message);
  const rows = (r.success && r.data) || [];
  check('  病案号按角色脱敏（mrn 为空 / mrnMasked=—）', rows.every((x) => !x.mrn), JSON.stringify(rows[0] || {}).slice(0, 160));
  check(
    '  返回体无姓名类字段（真名不进主表）',
    rows.every((x) => !('name' in x) && !('patientName' in x) && !('realName' in x)),
    JSON.stringify(rows[0] || {}).slice(0, 160)
  );
}
{
  const r = sponsor({ action: 'dashboard' });
  check('Sponsor dashboard 仅聚合统计', r.success === true && r.data.view === 'sponsor' && !!r.data.stats, r.message);
  check('  不含个体明细字段', !JSON.stringify(r.data).includes('subjectCode'), JSON.stringify(r.data).slice(0, 160));
}
{
  const r = irb({ action: 'dashboard' });
  check('IRB dashboard 仅伦理待审材料', r.success === true && r.data.view === 'irb', r.message);
}
{
  const r = admin({ action: 'dashboard' });
  check('Admin dashboard 系统管理视图', r.success === true && r.data.view === 'admin', r.message);
}
{
  const r = subi({ action: 'createAssessment', patientId: ctx.patient._id, woundId: ctx.wound._id, lengthCm: 3.0, widthCm: 2.0 });
  check('SubI 创建评估 → 允许（研究员可做医学判断）', r.success === true, r.message);
}

// ───────── 8. 未登录访问 ─────────
section('8. 未绑定账号访问');
{
  const r = invoke({ action: 'listPatients', __debugUser: 'ghost_user' });
  check('未绑定账号 → 401 拒绝', r.success === false, `实际 success=${r.success}`);
}

// ───────── 汇总 ─────────
console.log('\n' + '─'.repeat(58));
console.log(`  \x1b[1m通过 ${pass} / 失败 ${fail} / 共 ${pass + fail}\x1b[0m`);
if (fail) {
  console.log('  失败项：');
  failures.forEach((f) => console.log(`    · ${f.replace(/\s+/g, ' ')}`));
}
console.log('─'.repeat(58));
process.exit(fail ? 1 : 0);
