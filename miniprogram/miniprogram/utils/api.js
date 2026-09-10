/**
 * 云函数调用封装 — 统一错误处理 + loading
 */
const { ENV_ID } = require('../config/env');

function call(action, params = {}, { loading = true } = {}) {
  if (loading) wx.showLoading({ title: '处理中…', mask: true });
  return wx.cloud
    .callFunction({ name: 'api', data: { action, ...params } })
    .then((res) => {
      if (loading) wx.hideLoading();
      const r = res.result || {};
      if (!r.success) {
        // 401 → 跳登录
        if (r.code === 401) {
          wx.reLaunch({ url: '/pages/login/login' });
        }
        return Promise.reject(r);
      }
      return r.data;
    })
    .catch((err) => {
      if (loading) wx.hideLoading();
      if (err && err.success === false) return Promise.reject(err);
      return Promise.reject({ success: false, message: err.errMsg || '网络异常', code: -1 });
    });
}

/** 上传创面照片到云存储（chooseMedia 压缩后天然剥离 EXIF GPS — PIPL/GCP） */
function uploadPhoto(cloudPath, filePath) {
  return wx.cloud.uploadFile({ cloudPath, filePath });
}

module.exports = { call, uploadPhoto, ENV_ID };
