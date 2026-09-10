/** 试验管理：研究中心（含负责人联系方式 W6）/ 方案 / 器械，三个 tab */
const app = getApp();
const { call } = require('../../utils/api');
const rbac = require('../../utils/rbac');

Page({
  data: {
    tab: 'centers',
    canManage: false,
    centers: [],
    protocols: [],
    docs: [],
    devices: [],
    showEdit: false,
    editForm: { centerId: '', name: '', leadPiName: '', piContact: '' },
  },

  onShow() {
    this.setData({ canManage: rbac.can(app.user, 'centerManage') });
    this.load();
  },

  switchTab(e) {
    this.setData({ tab: e.currentTarget.dataset.t });
    this.load();
  },

  async load() {
    const t = this.data.tab;
    try {
      if (t === 'centers') {
        this.setData({ centers: await call('listCenters') });
      } else if (t === 'protocols') {
        const ps = await call('listProtocols');
        this.setData({ protocols: ps });
        if (ps.length > 0) {
          this.setData({ docs: await call('listProtocolDocs', { protocolId: ps[0]._id }) });
        }
      } else {
        this.setData({ devices: await call('listDevices') });
      }
    } catch (e) { /* api 层已处理 */ }
  },

  openEdit(e) {
    const c = e.currentTarget.dataset.c;
    this.setData({
      showEdit: true,
      editForm: { centerId: c._id, name: c.name, leadPiName: c.leadPiName || '', piContact: c.piContact || '' },
    });
  },
  closeEdit() { this.setData({ showEdit: false }); },
  onEditInput(e) {
    this.setData({ [`editForm.${e.currentTarget.dataset.field}`]: e.detail.value });
  },
  async submitEdit() {
    const f = this.data.editForm;
    try {
      await call('updateCenter', { centerId: f.centerId, leadPiName: f.leadPiName, piContact: f.piContact });
      this.setData({ showEdit: false });
      wx.showToast({ title: '已保存（入审计）', icon: 'none' });
      this.load();
    } catch (e) {
      wx.showToast({ title: e.message || '保存失败', icon: 'none' });
    }
  },

  callContact(e) {
    const phone = e.currentTarget.dataset.phone.split(' ')[0];
    if (phone && /^\d/.test(phone)) wx.makePhoneCall({ phoneNumber: phone });
  },
});
