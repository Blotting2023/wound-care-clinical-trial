/**
 * 拍照/选图 → 上传云存储 → 跳量表页
 * PIPL/GCP：chooseMedia 压缩通道天然剥离 EXIF（含 GPS），端上不保留原图元数据。
 */
const app = getApp();
const { call, uploadPhoto } = require('../../utils/api');

Page({
  data: {
    patientId: '',
    woundId: '',
    tempFile: '',
    deviceModel: '',
  },

  onLoad(options) {
    const sys = wx.getSystemInfoSync();
    this.setData({
      patientId: options.patientId || '',
      woundId: options.woundId || '',
      deviceModel: `${sys.brand} ${sys.model} / 微信 ${sys.version}`,
    });
  },

  takePhoto() {
    wx.chooseMedia({
      count: 1,
      mediaType: ['image'],
      sourceType: ['camera', 'album'],
      sizeType: ['compressed'], // 压缩 → EXIF 剥离
      success: (res) => {
        this.setData({ tempFile: res.tempFiles[0].tempFilePath });
      },
    });
  },

  async submit() {
    const { tempFile, woundId, patientId, deviceModel } = this.data;
    if (!tempFile) {
      wx.showToast({ title: '请先拍照或选择照片', icon: 'none' });
      return;
    }
    if (!woundId) {
      // 未指定部位 → 先去患者详情选部位
      wx.showToast({ title: '请从受试者详情选择创面部位后评估', icon: 'none' });
      return;
    }
    try {
      wx.showLoading({ title: '上传照片…', mask: true });
      const cloudPath = `wound-photos/${woundId}/${Date.now()}.jpg`;
      const up = await uploadPhoto(cloudPath, tempFile);
      wx.hideLoading();
      // 记录 fileID，跳量表页填数据
      wx.navigateTo({
        url: `/pages/scale/scale?patientId=${patientId}&woundId=${woundId}&photoFileId=${encodeURIComponent(up.fileID)}&deviceModel=${encodeURIComponent(deviceModel)}`,
      });
    } catch (e) {
      wx.hideLoading();
      wx.showToast({ title: '照片上传失败', icon: 'none' });
    }
  },
});
