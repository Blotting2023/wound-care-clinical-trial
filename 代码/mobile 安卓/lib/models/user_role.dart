/// 6 角色 RBAC — V1 demo 默认只演示 PI / Admin / CRC 三个角色，
/// 其它 3 个（SubI / Sponsor / IRB）保留 enum 占位，登录入口也保留。
///
/// 设计依据：合规规范/V1开发任务卡.md §W4.3 6 角色权限矩阵。
library;

/// 6 角色 — 跟 GCP 临床试验岗位一一对应。
/// 中文 / 拼音双标签，便于 UI 显示。
enum UserRole {
  PI,
  SubI,
  CRC,
  Sponsor,
  IRB,
  Admin;

  /// 中文显示名（UI 用）
  String get displayName {
    switch (this) {
      case UserRole.PI:
        return '主要研究者';
      case UserRole.SubI:
        return '副研究者';
      case UserRole.CRC:
        return '临床研究协调员';
      case UserRole.Sponsor:
        return '申办者';
      case UserRole.IRB:
        return '伦理委员会';
      case UserRole.Admin:
        return '系统管理员';
    }
  }

  /// 短代号（demo 登录用）
  String get shortCode {
    switch (this) {
      case UserRole.PI:
        return 'PI';
      case UserRole.SubI:
        return 'SubI';
      case UserRole.CRC:
        return 'CRC';
      case UserRole.Sponsor:
        return 'SP';
      case UserRole.IRB:
        return 'IRB';
      case UserRole.Admin:
        return 'ADM';
    }
  }

  /// 字符串解析（demo 后端 JWT 用）
  static UserRole? tryParse(String? s) {
    if (s == null) return null;
    for (final r in UserRole.values) {
      if (r.name == s || r.shortCode == s) return r;
    }
    return null;
  }
}

/// 权限动作 — 用 `资源:动作` 字符串命名，跟任务卡 §W4.3 矩阵完全一致。
class Permission {
  // patient
  static const patientCreate = 'patient:create';
  static const patientUpdateBasic = 'patient:update_basic';
  static const patientReadIdentity = 'patient:read_identity';

  // assessment
  static const assessmentCreate = 'assessment:create';
  static const assessmentUpdate = 'assessment:update';
  static const assessmentLock = 'assessment:lock';

  // consent
  static const consentSign = 'consent:sign';
  static const consentWithdraw = 'consent:withdraw';
  static const consentConfigure = 'consent:configure';

  // audit
  static const auditRead = 'audit:read';
  static const auditExport = 'audit:export';

  // pdf
  static const pdfExport = 'pdf:export';

  // trial management
  static const protocolManage = 'protocol:manage';
  static const centerManage = 'center:manage';
  static const deviceManage = 'device:manage';

  // data
  static const dataDestroy = 'data:destroy';
}

/// 6 角色的权限矩阵 — 跟任务卡 §W4.3 完全对齐。
class RolePermissionMatrix {
  /// 拿到角色对应的权限集合。
  ///
  /// Admin 用通配符 `'*'` 表示"全部"，所以在 checkPermission 里要
  /// 单独 short-circuit。
  static List<String> permissionsOf(UserRole role) {
    switch (role) {
      case UserRole.PI:
        return const [
          Permission.patientCreate,
          Permission.patientUpdateBasic,
          Permission.patientReadIdentity,
          Permission.assessmentCreate,
          Permission.assessmentUpdate,
          Permission.assessmentLock,
          Permission.consentSign,
          Permission.consentWithdraw,
          Permission.auditRead,
          Permission.auditExport,
          Permission.pdfExport,
          Permission.protocolManage,
          Permission.centerManage,
          Permission.deviceManage,
        ];
      case UserRole.SubI:
        return const [
          Permission.patientCreate,
          Permission.patientUpdateBasic,
          Permission.patientReadIdentity,
          Permission.assessmentCreate,
          Permission.assessmentUpdate,
          Permission.assessmentLock,
          Permission.auditRead,
          Permission.pdfExport,
        ];
      case UserRole.CRC:
        // 按 GCP 2020+ CRC 行业指南：CRC 经 PI 书面授权可录入**非医学判断**
        // 性字段（合并用药/合并疾病/AE 列表本身/随访日期/样本记录），但
        // 创面疗效评估（创面打分/分级/医学判断）必须由研究者（PI/SubI）
        // 亲自完成。V1 demo 核心字段就是创面打分，所以 CRC 暂不录数据，
        // 保留 auditRead + pdfExport 以承担"协调查看"职责。
        return const [
          Permission.auditRead,
          Permission.pdfExport,
        ];
      case UserRole.Sponsor:
        // 申办方：监查视图，不录数据。
        return const [
          Permission.auditRead,
          Permission.pdfExport,
          Permission.deviceManage,
        ];
      case UserRole.IRB:
        // 伦理委员会：审阅 eConsent/SAE/方案偏离，不录数据。
        return const [
          Permission.auditRead,
          Permission.auditExport,
          Permission.consentWithdraw,
        ];
      case UserRole.Admin:
        // 系统管理员：通配，但临床数据操作（assessmentCreate /
        // patientCreate / assessmentLock）按老胡反馈不应启用，
        // 仅承担系统配置 + 全量审计查看。
        return const [
          Permission.auditRead,
          Permission.auditExport,
          Permission.pdfExport,
          Permission.protocolManage,
          Permission.centerManage,
          Permission.deviceManage,
        ];
    }
  }

  /// 菜单可见性 — 把"角色 → 可见的菜单 key"硬编码在客户端。
  ///
  /// 客户端先做一次过滤，**但**服务端权限检查是兜底（防绕过）。
  static Set<String> visibleMenuKeys(UserRole role) {
    switch (role) {
      case UserRole.PI:
        return const {
          'workbench',
          'patients',
          'audit',
          'settings',
          'protocols',
          'centers',
          'devices',
          'consent',
          'institution',
        };
      case UserRole.SubI:
        return const {
          'workbench',
          'patients',
          'audit',
          'settings',
          'consent',
        };
      case UserRole.CRC:
        return const {
          'workbench',
          'patients',
          'devices',
          'settings',
          'consent',
        };
      case UserRole.Sponsor:
        return const {
          'audit',
          'settings',
          'devices',
        };
      case UserRole.IRB:
        return const {
          'audit',
          'settings',
          'consent',
        };
      case UserRole.Admin:
        // Admin 全部可见（含机构设置）
        return const {
          'workbench',
          'patients',
          'audit',
          'settings',
          'protocols',
          'centers',
          'devices',
          'consent',
          'institution',
          'admin',
        };
    }
  }
}
