const app = getApp();
const { call } = require('../../utils/api');
const rbac = require('../../utils/rbac');

Page({
  data: {
    user: null,
    roleTag: '',
    view: 'clinical',
    stats: null,
    recent: [],
    retentionUntil: '',
    pendingConsents: [],
    canCreate: false,
  },

  onShow() {
    const user = app.user;
    if (!user) {
      wx.reLaunch({ url: '/pages/login/login' });
      return;
    }
    this.setData({
      user,
      roleTag: rbac.roleDisplay(user.role),
      canCreate: rbac.can(user, 'assessmentCreate'),
    });
    this.load();
  },

  async load() {
    try {
      const d = await call('dashboard', {}, { loading: false });
      this.setData({
        view: d.view,
        stats: d.stats || null,
        recent: d.recent || [],
        retentionUntil: d.retentionUntil || '',
        pendingConsents: d.pendingConsents || [],
      });
    } catch (e) {
      // 未绑定等情况 api.js 已处理跳转
    }
  },

  goNew() {
    if (!this.data.canCreate) return;
    wx.navigateTo({ url: '/pages/patients/patients?mode=pick' });
  },

  goPatients() {
    wx.navigateTo({ url: '/pages/patients/patients' });
  },

  goWound(e) {
    wx.navigateTo({ url: `/pages/wound-detail/wound-detail?woundId=${e.currentTarget.dataset.wound}&patientId=${e.currentTarget.dataset.patient}` });
  },

  goConsent() {
    wx.navigateTo({ url: '/pages/consent/consent' });
  },

  goTrial() {
    wx.navigateTo({ url: '/pages/trial/trial' });
  },

  goMy() {
    wx.navigateTo({ url: '/pages/my/my' });
  },
});
