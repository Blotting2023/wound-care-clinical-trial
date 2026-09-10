/**
 * 量表 + CRF 三态字段 → 提交评估记录（W3 对齐：三态 ND/UN/NA，后端守门）
 */
const { call } = require('../../utils/api');

const CRF_FIELDS = [
  { key: 'medication', label: '合并用药', options: ['ND', 'UN', 'NA'] },
  { key: 'disease', label: '合并疾病', options: ['ND', 'UN', 'NA'] },
  { key: 'ae', label: '不良事件 AE', options: ['ND', 'UN', 'NA'] },
];

Page({
  data: {
    patientId: '', woundId: '', photoFileId: '', deviceModel: '',
    crfFields: CRF_FIELDS,
    crf: { medication: 'ND', disease: 'ND', ae: 'ND' },
    lengthCm: '', widthCm: '',
    // VSS 量表（简化 4 项 0-3 分）
    vss: [
      { key: 'pigment', label: '色素沉着', score: 0 },
      { key: 'vascular', label: '血管分布', score: 0 },
      { key: 'thickness', label: '厚度', score: 0 },
      { key: 'relief', label: '凹凸不平', score: 0 },
    ],
    vssTotal: 0,
    busy: false,
  },

  onLoad(options) {
    this.setData({
      patientId: options.patientId || '',
      woundId: options.woundId || '',
      photoFileId: decodeURIComponent(options.photoFileId || ''),
      deviceModel: decodeURIComponent(options.deviceModel || ''),
    });
  },

  onDim(e) {
    const { field } = e.currentTarget.dataset;
    this.setData({ [`lengthCm`]: field === 'l' ? e.detail.value : this.data.lengthCm });
  },

  onNumInput(e) {
    const f = e.currentTarget.dataset.field;
    this.setData({ [f]: e.detail.value });
  },

  onCrfPick(e) {
    const { field, idx } = e.currentTarget.dataset;
    this.setData({ [`crf.${field}`]: this.data.crfFields.find((f) => f.key === field).options[idx] });
  },

  onVssPick(e) {
    const { idx, score } = e.currentTarget.dataset;
    this.setData({
      [`vss[${idx}].score`]: Number(score),
      vssTotal: this.data.vss.reduce((s, v, i) => s + (i === Number(idx) ? Number(score) : v.score), 0),
    });
  },

  async submit() {
    const { lengthCm, widthCm, busy } = this.data;
    const l = Number(lengthCm), w = Number(widthCm);
    if (busy) return;
    if (!(l > 0) || !(w > 0)) {
      wx.showToast({ title: '请填写创面长宽（cm）', icon: 'none' });
      return;
    }
    this.setData({ busy: true });
    try {
      await call('createAssessment', {
        patientId: this.data.patientId,
        woundId: this.data.woundId,
        lengthCm: l,
        widthCm: w,
        vssScore: this.data.vssTotal,
        tissueJson: {},
        crf: this.data.crf,
        photoFileId: this.data.photoFileId,
        deviceModel: this.data.deviceModel,
      });
      wx.showToast({ title: '评估已提交', icon: 'success' });
      setTimeout(() => wx.navigateBack({ delta: 2 }), 800);
    } catch (e) {
      wx.showToast({ title: e.message || '提交失败', icon: 'none' });
    } finally {
      this.setData({ busy: false });
    }
  },
});
