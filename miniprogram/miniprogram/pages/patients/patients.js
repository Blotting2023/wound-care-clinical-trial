const app = getApp();
const { call } = require('../../utils/api');
const rbac = require('../../utils/rbac');

Page({
  data: {
    mode: 'list', // list | pick（从工作台"新建"进来选受试者）
    canCreate: false,
    patients: [],
    showCreate: false,
    form: { mrn: '', gender: '男', birthYear: '' },
  },

  onLoad(options) {
    const user = app.user;
    this.setData({
      mode: options.mode === 'pick' ? 'pick' : 'list',
      canCreate: rbac.can(user, 'patientCreate'),
    });
  },

  onShow() {
    this.load();
  },

  async load() {
    try {
      const patients = await call('listPatients');
      this.setData({ patients });
    } catch (e) { /* api 层已提示 */ }
  },

  openCreate() {
    this.setData({ showCreate: true });
  },

  closeCreate() {
    this.setData({ showCreate: false });
  },

  onFormInput(e) {
    this.setData({ [`form.${e.currentTarget.dataset.field}`]: e.detail.value });
  },

  onGender(e) {
    this.setData({ 'form.gender': e.currentTarget.dataset.g });
  },

  async submitCreate() {
    const f = this.data.form;
    if (!f.mrn.trim()) {
      wx.showToast({ title: '请输入病案号', icon: 'none' });
      return;
    }
    try {
      await call('createPatient', {
        mrn: f.mrn.trim(),
        gender: f.gender,
        birthYear: f.birthYear,
      });
      this.setData({ showCreate: false, form: { mrn: '', gender: '男', birthYear: '' } });
      wx.showToast({ title: '已建档（鉴认代码自动生成）', icon: 'none' });
      this.load();
    } catch (e) {
      wx.showToast({ title: e.message || '建档失败', icon: 'none' });
    }
  },

  tapPatient(e) {
    const id = e.currentTarget.dataset.id;
    const suffix = this.data.mode === 'pick' ? '&mode=pick' : '';
    wx.navigateTo({ url: `/pages/patient-detail/patient-detail?patientId=${id}${suffix}` });
  },
});
