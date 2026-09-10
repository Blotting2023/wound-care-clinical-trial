/** 我的：角色信息 + 权限列表 + 审计链校验（Admin/PI）+ 退出 */
const app = getApp();
const { call } = require('../../utils/api');
const rbac = require('../../utils/rbac');

Page({
  data: {
    user: null,
    roleDisplay: '',
    roleColor: '',
    permNames: [],
    chainResult: '',
  },

  onShow() {
    const u = app.user;
    if (!u) {
      wx.reLaunch({ url: '/pages/login/login' });
      return;
    }
    const NAME = {
      'patient:create': '建档', 'patient:update_basic': '修改基本信息',
      'assessment:create': '新建评估', 'assessment:update': '修改评估',
      'assessment:lock': 'PIN 锁定', 'consent:sign': '知情签署',
      'consent:withdraw': '知情撤回', 'consent:configure': '知情配置',
      'audit:read': '查看审计', 'audit:export': '导出审计',
      'pdf:export': '数据导出', 'protocol:manage': '方案管理',
      'center:manage': '中心管理', 'device:manage': '器械管理',
      'data:destroy': '数据销毁', 'patient:read_identity': '查看身份',
    };
    this.setData({
      user: u,
      roleDisplay: rbac.roleDisplay(u.role),
      roleColor: rbac.roleColor(u.role),
      permNames: (u.permissions || []).map((p) => NAME[p] || p),
    });
  },

  async verifyChain() {
    try {
      const r = await call('auditVerify');
      this.setData({
        chainResult: r.ok ? `✅ 哈希链完整（${r.count} 条记录，可溯源）` : `❌ 链断裂于 seq ${r.brokenAt}`,
      });
    } catch (e) {
      wx.showToast({ title: e.message || '校验失败', icon: 'none' });
    }
  },

  goTrial() { wx.navigateTo({ url: '/pages/trial/trial' }); },
  goConsent() { wx.navigateTo({ url: '/pages/consent/consent' }); },

  logout() {
    app.clearUser();
    wx.reLaunch({ url: '/pages/login/login' });
  },
});
