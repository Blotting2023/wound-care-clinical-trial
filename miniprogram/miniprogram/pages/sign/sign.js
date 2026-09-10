/**
 * PIN 二次鉴别 → PI 锁定评估（21 CFR Part 11 简版）
 * 签名含义固定：PI 确认记录准确完整；签名与记录不可分离（服务端审计）。
 */
const { call } = require('../../utils/api');

Page({
  data: {
    assessmentId: '',
    pin: '',
    busy: false,
  },

  onLoad(options) {
    this.setData({ assessmentId: options.assessmentId });
  },

  onPin(e) {
    this.setData({ pin: e.detail.value });
  },

  async doSign() {
    const { pin, busy } = this.data;
    if (busy) return;
    if (pin.length !== 6) {
      wx.showToast({ title: '请输入 6 位 PIN', icon: 'none' });
      return;
    }
    this.setData({ busy: true });
    try {
      const r = await call('lockAssessment', { assessmentId: this.data.assessmentId, pin });
      wx.showModal({
        title: '签名成功',
        content: `记录已锁定，留存至 ${r.retentionUntil}（GCP §63）`,
        showCancel: false,
        success: () => wx.navigateBack(),
      });
    } catch (e) {
      wx.showToast({ title: e.message || '签名失败', icon: 'none' });
    } finally {
      this.setData({ busy: false, pin: '' });
    }
  },
});
