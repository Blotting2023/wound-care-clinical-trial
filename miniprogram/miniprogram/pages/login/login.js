const app = getApp();
const { call } = require('../../utils/api');

Page({
  data: {
    username: '',
    password: '',
    busy: false,
  },

  onInput(e) {
    this.setData({ [e.currentTarget.dataset.field]: e.detail.value });
  },

  async doLogin() {
    const { username, password, busy } = this.data;
    if (!username.trim() || busy) {
      wx.showToast({ title: '请输入工号', icon: 'none' });
      return;
    }
    this.setData({ busy: true });
    try {
      const user = await call('login', { username: username.trim(), password });
      app.setUser(user);
      wx.reLaunch({ url: '/pages/home/home' });
    } catch (e) {
      wx.showToast({ title: e.message || '登录失败', icon: 'none' });
    } finally {
      this.setData({ busy: false });
    }
  },

  fillDemo(e) {
    this.setData({ username: e.currentTarget.dataset.u, password: 'demo' });
  },
});
