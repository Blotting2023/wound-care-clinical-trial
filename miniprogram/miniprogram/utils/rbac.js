/**
 * 客户端 RBAC — 菜单/按钮可见性判断（服务端仍逐 action 守门，双保险）
 */
const WRITE_ROLES = ['PI', 'SubI']; // GCP §4：仅研究者可录入

const PERMISSIONS = {
  patientCreate: ['PI', 'SubI'],
  assessmentCreate: ['PI', 'SubI'],
  assessmentLock: ['PI'],
  consentReview: ['PI'],
  centerManage: ['PI', 'Admin'],
  protocolManage: ['PI', 'Admin'],
  auditRead: ['PI', 'SubI', 'CRC', 'Sponsor', 'IRB', 'Admin'],
  seeIdentity: ['PI', 'SubI', 'Admin'], // PIPL：病案号仅研究团队可见
};

function can(user, perm) {
  if (!user) return false;
  return (PERMISSIONS[perm] || []).includes(user.role);
}

function roleDisplay(role) {
  return {
    PI: '主要研究者', SubI: '副研究者', CRC: '临床研究协调员',
    Sponsor: '申办者', IRB: '伦理委员会', Admin: '系统管理员',
  }[role] || role;
}

function roleColor(role) {
  return {
    PI: '#0066CC', SubI: '#0066CC', CRC: '#34C759',
    Sponsor: '#FF9500', IRB: '#AF52DE', Admin: '#8E8E93',
  }[role] || '#8E8E93';
}

module.exports = { can, roleDisplay, roleColor };
