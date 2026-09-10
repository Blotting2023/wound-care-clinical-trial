/**
 * 6 角色 RBAC — 与 Flutter 版 lib/models/user_role.dart（W4.6 收紧版）完全对齐。
 * 合规依据：
 * - GCP 2020 §4 医学判断必须研究者本人完成 → 仅 PI/SubI 可创面打分/新建评估
 * - GCP 2020 §5 申办者最小必要 → Sponsor 仅聚合统计
 * - GCP 2020 §6 IRB 仅伦理相关
 * - PIPL §6 最小必要原则
 */

const ROLES = ['PI', 'SubI', 'CRC', 'Sponsor', 'IRB', 'Admin'];

const DISPLAY_NAME = {
  PI: '主要研究者',
  SubI: '副研究者',
  CRC: '临床研究协调员',
  Sponsor: '申办者',
  IRB: '伦理委员会',
  Admin: '系统管理员',
};

const P = {
  patientCreate: 'patient:create',
  patientUpdateBasic: 'patient:update_basic',
  patientReadIdentity: 'patient:read_identity',
  assessmentCreate: 'assessment:create',
  assessmentUpdate: 'assessment:update',
  assessmentLock: 'assessment:lock',
  consentSign: 'consent:sign',
  consentWithdraw: 'consent:withdraw',
  consentConfigure: 'consent:configure',
  auditRead: 'audit:read',
  auditExport: 'audit:export',
  pdfExport: 'pdf:export',
  protocolManage: 'protocol:manage',
  centerManage: 'center:manage',
  deviceManage: 'device:manage',
  dataDestroy: 'data:destroy',
};

/** 角色权限矩阵 — 与 Flutter 端 W4.6 收紧版一致 */
const MATRIX = {
  PI: [
    P.patientCreate, P.patientUpdateBasic, P.patientReadIdentity,
    P.assessmentCreate, P.assessmentUpdate, P.assessmentLock,
    P.consentSign, P.consentWithdraw, P.consentConfigure,
    P.auditRead, P.pdfExport, P.protocolManage, P.centerManage, P.deviceManage,
  ],
  SubI: [
    P.patientCreate, P.patientUpdateBasic, P.patientReadIdentity,
    P.assessmentCreate, P.assessmentUpdate,
    P.consentSign, P.auditRead, P.pdfExport,
  ],
  // GCP §4：CRC 只读（V1 收紧，创面打分属医学判断）
  CRC: [P.auditRead, P.pdfExport],
  // GCP §5：Sponsor 仅监查统计，无 dataDestroy
  Sponsor: [P.auditRead, P.pdfExport],
  // GCP §6：IRB 仅伦理相关
  IRB: [P.auditRead, P.auditExport, P.consentWithdraw],
  Admin: [
    P.auditRead, P.auditExport, P.protocolManage, P.centerManage,
    P.deviceManage, P.pdfExport,
  ],
};

/** 用户名前缀派角色（与 Flutter demo 一致，默认 CRC） */
function roleFromUsername(username) {
  const u = (username || '').toLowerCase();
  if (u.startsWith('pi')) return 'PI';
  if (u.startsWith('subi')) return 'SubI';
  if (u.startsWith('crc')) return 'CRC';
  if (u.startsWith('sponsor')) return 'Sponsor';
  if (u.startsWith('irb')) return 'IRB';
  if (u.startsWith('admin')) return 'Admin';
  return 'CRC';
}

function permissionsOf(role) {
  return MATRIX[role] || [];
}

function can(user, permission) {
  if (!user || !user.role) return false;
  if (user.role === 'PI') {
    // PI 含全部研究侧权限（不含 dataDestroy）
    return MATRIX.PI.includes(permission);
  }
  return permissionsOf(user.role).includes(permission);
}

/** 角色是否可见真实病案号（PIPL 数据最小化：仅 PI/SubI/Admin） */
function canSeeIdentity(role) {
  return role === 'PI' || role === 'SubI' || role === 'Admin';
}

module.exports = { ROLES, DISPLAY_NAME, P, MATRIX, roleFromUsername, permissionsOf, can, canSeeIdentity };
