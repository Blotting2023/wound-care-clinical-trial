const { ENV_ID } = require('./config/env');

App({
  globalData: {
    user: null, // {userId, username, displayName, role, permissions}
  },

  onLaunch() {
    if (!wx.cloud) {
      console.error('基础库过低，请升级微信');
      return;
    }
    wx.cloud.init({ env: ENV_ID, traceUser: true });
    this.restoreSession();
  },

  restoreSession() {
    const user = wx.getStorageSync('wound_user');
    if (user && user.userId) this.globalData.user = user;
  },

  setUser(u) {
    this.globalData.user = u;
    wx.setStorageSync('wound_user', u);
  },

  clearUser() {
    this.globalData.user = null;
    wx.removeStorageSync('wound_user');
  },

  get user() {
    return this.globalData.user;
  },
});
