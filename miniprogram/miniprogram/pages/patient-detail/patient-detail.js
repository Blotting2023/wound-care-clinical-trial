const app = getApp();
const { call } = require('../../utils/api');
const rbac = require('../../utils/rbac');

Page({
  data: {
    patientId: '',
    mode: '',
    patient: null,
    canManage: false,
    showCreate: false,
    form: { label: '', bodyPart: '' },
  },

  onLoad(options) {
    this.setData({
      patientId: options.patientId,
      mode: options.mode || '',
      canManage: rbac.can(app.user, 'patientCreate'),
    });
  },

  onShow() {
    this.load();
  },

  async load() {
    try {
      const p = await call('getPatient', { patientId: this.data.patientId });
      this.setData({ patient: p });
      wx.setNavigationBarTitle({ title: p.subjectCode });
    } catch (e) {
      wx.showToast({ title: e.message || '加载失败', icon: 'none' });
    }
  },

  openCreate() { this.setData({ showCreate: true }); },
  closeCreate() { this.setData({ showCreate: false }); },

  onFormInput(e) {
    this.setData({ [`form.${e.currentTarget.dataset.field}`]: e.detail.value });
  },

  async submitCreate() {
    const f = this.data.form;
    if (!f.label.trim()) {
      wx.showToast({ title: '请输入部位名称', icon: 'none' });
      return;
    }
    try {
      await call('createWound', {
        patientId: this.data.patientId,
        label: f.label.trim(),
        bodyPart: f.bodyPart.trim(),
      });
      this.setData({ showCreate: false, form: { label: '', bodyPart: '' } });
      this.load();
    } catch (e) {
      wx.showToast({ title: e.message || '创建失败', icon: 'none' });
    }
  },

  goWound(e) {
    wx.navigateTo({
      url: `/pages/wound-detail/wound-detail?woundId=${e.currentTarget.dataset.id}&patientId=${this.data.patientId}`,
    });
  },

  // pick 模式：选中受试者 → 直接新建评估（拍照）
  startAssess() {
    wx.navigateTo({
      url: `/pages/capture/capture?patientId=${this.data.patientId}`,
    });
  },
});
