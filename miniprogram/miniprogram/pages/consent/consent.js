/**
 * eConsent B 通道（老胡所在医院默认）：纸质知情书拍照上传 + 见证人 + PI 审核
 * IRB 在此看待审队列；PI 直接审核。
 */
const app = getApp();
const { call, uploadPhoto } = require('../../utils/api');
const rbac = require('../../utils/rbac');

Page({
  data: {
    role: '',
    isPI: false,
    tempFile: '',
    patients: [],
    patientIndex: 0,
    signedDate: '',
    witnessName: '',
    list: [],
    busy: false,
  },

  onShow() {
    const user = app.user;
    this.setData({ role: user.role, isPI: user.role === 'PI' });
    this.load();
  },

  async load() {
    try {
      const [patients, list] = await Promise.all([
        call('listPatients'),
        call('listConsents'),
      ]);
      this.setData({ patients, list });
    } catch (e) { /* api 层已处理 */ }
  },

  choosePhoto() {
    wx.chooseMedia({
      count: 1,
      mediaType: ['image'],
      sourceType: ['camera', 'album'],
      sizeType: ['compressed'],
      success: (res) => this.setData({ tempFile: res.tempFiles[0].tempFilePath }),
    });
  },

  onPatient(e) { this.setData({ patientIndex: Number(e.detail.value) }); },
  onDate(e) { this.setData({ signedDate: e.detail.value }); },
  onWitness(e) { this.setData({ witnessName: e.detail.value }); },

  async submitUpload() {
    const { tempFile, patients, patientIndex, signedDate, witnessName, busy } = this.data;
    if (busy) return;
    if (!tempFile || patients.length === 0) {
      wx.showToast({ title: '请拍照并选择受试者', icon: 'none' });
      return;
    }
    this.setData({ busy: true });
    try {
      wx.showLoading({ title: '上传中…', mask: true });
      const up = await uploadPhoto(`consents/${patients[patientIndex]._id}/${Date.now()}.jpg`, tempFile);
      wx.hideLoading();
      await call('uploadConsent', {
        patientId: patients[patientIndex]._id,
        photoFileId: up.fileID,
        signedDate, witnessName,
      });
      wx.showToast({ title: '已提交，等待 PI 审核', icon: 'none' });
      this.setData({ tempFile: '', witnessName: '', signedDate: '' });
      this.load();
    } catch (e) {
      wx.hideLoading();
      wx.showToast({ title: e.message || '提交失败', icon: 'none' });
    } finally {
      this.setData({ busy: false });
    }
  },

  async review(e) {
    const { id, approve } = e.currentTarget.dataset;
    const that = this;
    wx.showModal({
      title: approve ? '通过审核' : '驳回',
      content: approve ? '确认知情同意签署真实有效？' : '确认知情件无效？',
      success: async (res) => {
        if (!res.confirm) return;
        try {
          await call('reviewConsent', { consentId: id, approve });
          wx.showToast({ title: '已处理', icon: 'none' });
          that.load();
        } catch (err) {
          wx.showToast({ title: err.message || '操作失败', icon: 'none' });
        }
      },
    });
  },

  previewPhoto(e) {
    const fid = e.currentTarget.dataset.fid;
    if (fid) wx.previewImage({ urls: [fid] });
  },
});
