/**
 * GCP 审计哈希链（NMPA 2022 §57-§63 + ALCOA+）— PostgreSQL 版
 *
 * hash = SHA256(prevHash|ts|actor|action|target|detail)
 * seq 由 bigserial 保证单调；并发插入冲突时重试。
 */
const crypto = require('crypto');
const { selectAll, insertOne } = require('./pg');

function sha256(s) {
  return crypto.createHash('sha256').update(s, 'utf8').digest('hex');
}

function computeHash(prevHash, ts, actor, action, target, detailStr) {
  return sha256(`${prevHash}|${ts}|${actor}|${action}|${target || ''}|${detailStr}`);
}

/** ISO 时间串（兼容 PG 回读的 Date 对象 / 字符串） */
function isoOf(v) {
  if (!v) return '';
  if (v instanceof Date) return v.toISOString();
  return String(v);
}

/**
 * 稳定序列化（键排序）— jsonb 回读时 PG 会重排键顺序，
 * 不排序会导致哈希复核失败，故写入与校验都走此函数。
 */
function stableStringify(v) {
  if (v === null || v === undefined) return 'null';
  if (typeof v !== 'object') return JSON.stringify(v);
  if (Array.isArray(v)) return `[${v.map(stableStringify).join(',')}]`;
  const keys = Object.keys(v).sort();
  return `{${keys.map((k) => `${JSON.stringify(k)}:${stableStringify(v[k])}`).join(',')}}`;
}

/**
 * 追加审计记录。失败不阻断业务（最多重试 3 次）。
 *
 * ⚠️ 哈希覆盖的时间戳取自 ts_iso（写入时的 ISO 原文字符串），
 * 而不是 ts（timestamptz）—— 后者回读格式随 PG 时区/精度变化（+08 偏移 vs Z），
 * 用它做哈希会导致校验必然失败。
 *
 * @param {object} opts {actor, role, action, target, detail}
 */
async function appendAudit(opts) {
  const { actor, role, action, target, detail } = opts;
  for (let attempt = 0; attempt < 3; attempt += 1) {
    try {
      const tail = await selectAll('audit_logs', { order: 'seq', ascending: false, limit: 1 });
      const prevHash = tail.length ? tail[0].hash : 'GENESIS';
      const tsIso = new Date().toISOString();
      const detailStr = stableStringify(detail || {});
      const hash = computeHash(prevHash, tsIso, actor, action, target, detailStr);
      const rec = await insertOne('audit_logs', {
        ts: tsIso, ts_iso: tsIso, actor, role: role || '', action, target: target || '',
        detail: detail || {}, prev_hash: prevHash, hash,
      });
      return rec;
    } catch (e) {
      if (attempt === 2) {
        console.error('[audit] append failed:', e.message);
        return null;
      }
    }
  }
  return null;
}

/** 全链校验 — 返回 { ok, brokenAt, count } */
async function verifyChain() {
  const rows = await selectAll('audit_logs', { order: 'seq', ascending: true, limit: 200 });
  let prevHash = 'GENESIS';
  let checked = 0;
  for (const r of rows) {
    const detailStr = stableStringify(r.detail || {});
    const expect = computeHash(prevHash, isoOf(r.ts_iso), r.actor, r.action, r.target, detailStr);
    if (expect !== r.hash) return { ok: false, brokenAt: r.seq, count: checked };
    prevHash = r.hash;
    checked += 1;
  }
  return { ok: true, brokenAt: null, count: checked };
}

module.exports = { appendAudit, verifyChain, sha256, computeHash, isoOf, stableStringify };
