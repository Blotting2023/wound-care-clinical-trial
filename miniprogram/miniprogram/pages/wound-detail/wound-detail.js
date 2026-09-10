const app = getApp();
const { call } = require('../../utils/api');
const rbac = require('../../utils/rbac');

Page({
  data: {
    woundId: '',
    patientId: '',
    canAssess: false,
    canLock: false,
    wound: null,
    assessments: [],
  },

  onLoad(options) {
    this.setData({
      woundId: options.woundId,
      patientId: options.patientId,
      canAssess: rbac.can(app.user, 'assessmentCreate'),
      canLock: rbac.can(app.user, 'assessmentLock'),
    });
  },

  onShow() {
    this.load();
  },

  async load() {
    try {
      const asm = await call('listAssessments', { woundId: this.data.woundId });
      this.setData({ assessments: asm });
      if (asm.length > 0) {
        wx.setNavigationBarTitle({ title: asm[0].woundLabel || '创面详情' });
      }
    } catch (e) { /* api 层已处理 */ }
  },

  goCapture() {
    wx.navigateTo({
      url: `/pages/capture/capture?patientId=${this.data.patientId}&woundId=${this.data.woundId}`,
    });
  },

  goSign(e) {
    const { id } = e.currentTarget.dataset;
    wx.navigateTo({ url: `/pages/sign/sign?assessmentId=${id}` });
  },

  previewPhoto(e) {
    const fid = e.currentTarget.dataset.fid;
    if (!fid) return;
    wx.previewImage({ urls: [fid] }); // cloud:// fileID 可直接预览
  },

  trend(assessments) {
    // 面积趋势简单呈现：面积变化列表已在页面展示，V2 加 canvas 折线
  },
});
