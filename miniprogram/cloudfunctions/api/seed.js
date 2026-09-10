/**
 * 种子数据 — PostgreSQL 版，与 Flutter 版 demo_backend.dart 对齐（V1 演示数据）。
 * 幂等：表非空则跳过。表结构由 migration 20260910140000_init_clinical_schema 创建。
 */
const { selectAll, insertOne, count } = require('./pg');

let _seeded = false;

async function seed() {
  if (_seeded) return true;

  // ---- users（demo 账号，待真实名单替换）----
  if ((await count('users')) === 0) {
    const demoUsers = [
      { username: 'pi_demo', display_name: '王立明', role: 'PI' },
      { username: 'subi_demo', display_name: '李秀芳', role: 'SubI' },
      { username: 'crc_demo', display_name: '张倩', role: 'CRC' },
      { username: 'sponsor_demo', display_name: '陈申', role: 'Sponsor' },
      { username: 'irb_demo', display_name: '赵伦理', role: 'IRB' },
      { username: 'admin_demo', display_name: '系统管理员', role: 'Admin' },
    ];
    for (const u of demoUsers) {
      await insertOne('users', { ...u, openid: '', active: true });
    }
  }

  // ---- centers ----
  if ((await count('centers')) === 0) {
    await insertOne('centers', {
      code: 'C01', name: '齐鲁医院', department: '烧伤整形外科',
      address: '济南市文化西路107号', irb_number: 'QL-IRB-2026-014',
      lead_pi_name: '王立明', pi_contact: '139-0531-8877 · lm.wang@qlhosp.cn',
    });
    await insertOne('centers', {
      code: 'C02', name: '山东省立医院', department: '创面修复科',
      address: '济南市经五路324号', irb_number: '',
      lead_pi_name: '', pi_contact: '',
    });
  }

  // ---- protocol ----
  if ((await count('protocols')) === 0) {
    await insertOne('protocols', {
      code: 'WC-RCT-2026',
      name: '新型创面敷料在慢性创面治疗中的有效性随机对照试验',
      version: 'v1.2', sponsor: '山东易测科技', phase: 'III',
      status: 'active', start_date: '2026-09-01',
      summary: '多中心、随机、平行对照设计，主要终点为创面面积缩小率。',
    });
  }

  // ---- devices ----
  if ((await count('devices')) === 0) {
    const seeds = [
      { code: 'DEV-2026-001', name: '新型创面敷料', batch_no: 'B20260801', status: 'in_stock' },
      { code: 'DEV-2026-002', name: '新型创面敷料', batch_no: 'B20260801', status: 'in_stock' },
      { code: 'DEV-2026-003', name: '新型创面敷料', batch_no: 'B20260802', status: 'in_stock' },
    ];
    for (const d of seeds) await insertOne('devices', { ...d, allocated_to: '' });
  }

  // ---- 方案文档示例 ----
  if ((await count('protocol_docs')) === 0) {
    const protocols = await selectAll('protocols', { limit: 1 });
    if (protocols.length) {
      await insertOne('protocol_docs', {
        protocol_id: protocols[0].id,
        file_name: 'WC-RCT-2026_主方案_v1.2.pdf',
        file_ext: 'pdf', file_size_bytes: 2411724, version: 'v1.2',
        uploaded_by: 'pi_demo',
      });
    }
  }

  _seeded = true;
  return true;
}

module.exports = { seed };
