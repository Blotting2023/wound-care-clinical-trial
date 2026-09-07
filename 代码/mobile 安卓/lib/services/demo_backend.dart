import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import '../models/consent_form.dart';
import '../models/user.dart';
import '../models/user_role.dart';
import 'audit_logger.dart';
import 'subject_code_generator.dart';
/// In-memory demo backend.
///
/// On top of the previous seed + workflow behaviour, this revision (2026-09-03)
/// adds the W1 of the GCP V1 milestone:
///
///   * **Subject code generation** — every patient is auto-tagged with a
///     `subjectCode` (`<PinyinInitials><4-digit-seq>`, e.g. `ZW0001`).
///   * **Identity map** — real names live in a separate, role-gated
///     `_identityMap`. The `/patients` and `/patients/:id` endpoints no
///     longer leak the name unless the caller has role `PI` / `Admin`.
///   * **Audit trail** — every PUT, POST, DELETE, SIGN and identity-access
///     call goes through `AuditLogger.I.record(...)`. The log is append-only
///     at the API level; the chain is sha256-hashed so any tampering breaks
///     the next link.
///
///   See `合规规范/差距清单与落地建议.md` §11 + `V1开发任务卡.md` W1.
class DemoBackend extends Interceptor {
  DemoBackend();

  final Map<String, Map<String, dynamic>> _patients = {};
  final Map<String, Map<String, dynamic>> _wounds = {};
  final Map<String, Map<String, dynamic>> _assessments = {};

  /// GCP W2 — 试验方案 / 中心 / 试用器械 / 台账.
  final Map<String, Map<String, dynamic>> _protocols = {};
  final Map<String, Map<String, dynamic>> _centers = {};
  final Map<String, Map<String, dynamic>> _allocations = {};
  final Map<String, Map<String, dynamic>> _devices = {};
  final Map<String, Map<String, dynamic>> _deviceUsageLogs = {};

  /// GCP W3.1 — 创面照片元数据存储（key = imageId）。
  /// 服务端做 COS 落地 + sha256 校验；demo 阶段存 in-memory 镜像。
  final Map<String, Map<String, dynamic>> _photoMetadata = {};

  /// GCP W3.2 — CRF 完成声明审计日志。
  /// 与 audit_logger 区分，专门追"PI 必签的 CRF 完成声明"事件。
  final List<Map<String, dynamic>> _crfCompletionDeclarations = [];

  /// W4.1 — 知情同意书存储。Key = consentId。
  final Map<String, Map<String, dynamic>> _consents = {};

  /// Encrypted identity map (mock). Keyed by `subjectCode`. In production
  /// this lives in `PatientIdentityMap` with KMS-encrypted columns.
  final Map<String, Map<String, dynamic>> _identityMap = {};

  /// Per-prefix sequence counter so each new patient gets a unique
  /// 4-digit sequence within their centre.
  final Map<String, int> _seqByPrefix = {};

  int _seq = 0;

  String _newId(String prefix) =>
      '${prefix}_${DateTime.now().millisecondsSinceEpoch}_${_seq++}';
  String _nowIso() => DateTime.now().toUtc().toIso8601String();

  /// Demo operator context. In production this is derived from the verified
  /// JWT — for the demo we hard-code a PI identity so identity-access works
  /// out of the box. **Mutated on every `/auth/login`** so all subsequent
  /// API calls carry the right role/operator id.
  static AuditContext _demoCtx = AuditContext(
    operatorId: 'demo-nurse-01',
    operatorName: '演示护士',
    operatorRole: 'PI',
    operatorIp: '127.0.0.1',
    deviceFingerprint: 'sim-iphone16pro',
    appVersion: '0.1.0',
  );

  /// 已登录用户缓存（demo 单会话；多会话需要 token→ctx map）
  static User? _currentUser;

  /// W4.3 — demo 登录时按 username 前缀派角色，方便老胡一秒钟切角色。
  /// 生产场景由真实 OAuth / LDAP 给 role，不允许客户端自报。
  UserRole _roleForUsername(String username) {
    final u = username.toLowerCase();
    if (u.startsWith('pi') || u.contains('pi')) return UserRole.PI;
    if (u.startsWith('subi') || u.contains('subi')) return UserRole.SubI;
    if (u.startsWith('admin') || u.contains('admin')) return UserRole.Admin;
    if (u.startsWith('sponsor') || u.contains('sponsor')) return UserRole.Sponsor;
    if (u.startsWith('irb')) return UserRole.IRB;
    return UserRole.CRC; // 默认最低权限
  }

  /// 把当前 demo 操作员的 display name 按角色生成。
  String _displayNameFor(String username, UserRole role) {
    final base = username.trim().isEmpty ? '演示用户' : username.trim();
    return '$base（${role.displayName}）';
  }

  /// 通用权限检查 — W4.1/W4.2 端点都会用。
  /// 返回 null 表示通过；返回 Response 表示 403。
  /// 调用方传 [options]（用于构造 Response）+ [requiredPermission]。
  Response<dynamic>? _checkPermission(
      RequestOptions options, String requiredPermission) {
    final user = _currentUser;
    if (user == null) {
      return Response<dynamic>(
        requestOptions: options,
        data: {'message': 'Unauthorized'},
        statusCode: 401,
      );
    }
    final perms = user.permissions;
    if (perms.contains('*')) return null; // Admin 通配
    if (perms.contains(requiredPermission)) return null;
    // 写审计：access denied
    AuditLogger.I.record(
      tableName: requiredPermission.split(':').first,
      recordId: 'n/a',
      opType: AuditOpType.accessDenied,
      afterValue: {
        'permission': requiredPermission,
        'role': user.role.name,
      },
      ctx: _demoCtx,
      reason: '越权访问被拒',
    );
    return Response<dynamic>(
      requestOptions: options,
      data: {
        'message':
            '权限不足：${user.role.displayName} 无权执行 $requiredPermission',
      },
      statusCode: 403,
    );
  }

  String _nextSubjectCode(String realName) {
    final prefix = const SubjectCodeGenerator().generate(realName, 0);
    // Sequence is global per prefix (per centre in production).
    final next = (_seqByPrefix[prefix] ?? 0) + 1;
    _seqByPrefix[prefix] = next;
    return const SubjectCodeGenerator().generate(realName, next);
  }

  /// Strip the deprecated `name` and `medicalRecordNo` fields before
  /// returning the patient to the client — unless the caller is a
  /// privileged role. Demo default is privileged.
  Map<String, dynamic> _patientForClient(
      Map<String, dynamic> raw, String callerRole) {
    final canSeeReal = callerRole == 'PI' ||
        callerRole == 'Admin' ||
        callerRole == 'SubI';
    final out = Map<String, dynamic>.from(raw);
    out['canViewRealName'] = canSeeReal;
    out['identityRecordId'] = raw['subjectCode'];
    if (!canSeeReal) {
      out.remove('name');
      out.remove('medicalRecordNo');
    }
    return out;
  }

  void _ensureSeeded() {
    if (_patients.isNotEmpty) return;
    final now = _nowIso();

    final seeds = <Map<String, dynamic>>[
      {
        'realName': '张伟',
        'patientCode': 'P-001',
        'medicalRecordNo': 'MRN-2026-001',
        'dateOfBirth': '1962-03-14',
        'gender': 'male',
      },
      {
        'realName': '李秀英',
        'patientCode': 'P-002',
        'medicalRecordNo': 'MRN-2026-002',
        'dateOfBirth': '1955-11-02',
        'gender': 'female',
      },
      {
        'realName': '王建国',
        'patientCode': 'P-003',
        'medicalRecordNo': 'MRN-2026-003',
        'dateOfBirth': '1970-07-21',
        'gender': 'male',
      },
    ];

    var pidx = 1;
    for (final s in seeds) {
      final realName = s['realName'] as String;
      final subjectCode = _nextSubjectCode(realName);
      final id = 'p$pidx';
      _patients[id] = {
        'id': id,
        'facilityId': 'f1',
        'subjectCode': subjectCode,
        // ignore: deprecated_member_use_from_same_package
        'patientCode': s['patientCode'],
        'name': realName,
        'medicalRecordNo': s['medicalRecordNo'],
        'dateOfBirth': s['dateOfBirth'],
        'gender': s['gender'],
        'createdAt': now,
        'updatedAt': now,
      };
      _identityMap[subjectCode] = {
        'subjectCode': subjectCode,
        'realName': realName,
        'medicalRecordNo': s['medicalRecordNo'],
        'encryptedBy': 'demo',
        'createdAt': now,
      };
      pidx++;
    }

    _wounds['w1'] = {
      'id': 'w1',
      'patientId': 'p1',
      'anatomicalLocation': '左小腿',
      'woundType': 'pressure injury',
      'etiology': 'pressure',
      'onsetDate': '2026-08-01T00:00:00Z',
      'protocolId': 'pr1',
      'centerId': 'c1',
      'deviceId': 'd1',
      'createdAt': now,
      'updatedAt': now,
    };
    _wounds['w2'] = {
      'id': 'w2',
      'patientId': 'p1',
      'anatomicalLocation': '骶尾部',
      'woundType': 'surgical',
      'etiology': 'post-op',
      'onsetDate': '2026-08-10T00:00:00Z',
      'protocolId': 'pr1',
      'centerId': 'c1',
      'deviceId': 'd2',
      'createdAt': now,
      'updatedAt': now,
    };
    _wounds['w3'] = {
      'id': 'w3',
      'patientId': 'p2',
      'anatomicalLocation': '右足跟',
      'woundType': 'diabetic ulcer',
      'etiology': 'diabetic',
      'onsetDate': '2026-07-20T00:00:00Z',
      'protocolId': 'pr1',
      'centerId': 'c1',
      'deviceId': 'd2',
      'createdAt': now,
      'updatedAt': now,
    };
    _wounds['w4'] = {
      'id': 'w4',
      'patientId': 'p3',
      'anatomicalLocation': '左前臂',
      'woundType': 'surgical',
      'etiology': 'post-op',
      'onsetDate': '2026-08-15T00:00:00Z',
      'protocolId': 'pr1',
      'centerId': 'c1',
      'deviceId': null,
      'createdAt': now,
      'updatedAt': now,
    };

    // 同时把方案/中心绑到 demo 3 个患者上
    _patients.forEach((pid, p) {
      p['protocolId'] = 'pr1';
      p['centerId'] = 'c1';
      p['enrollmentDate'] = now;
    });

    final seed = _assess('w1', 'p1', 'demo-nurse-01');
    seed['status'] = 'locked';
    seed['aiAreaCm2'] = 12.5;
    seed['aiLengthCm'] = 4.2;
    seed['aiWidthCm'] = 3.1;
    seed['aiPolygonJson'] = jsonEncode([
      {'x': 450, 'y': 340},
      {'x': 630, 'y': 415},
      {'x': 710, 'y': 600},
      {'x': 632, 'y': 785},
      {'x': 450, 'y': 862},
      {'x': 268, 'y': 786},
      {'x': 190, 'y': 600},
      {'x': 266, 'y': 412},
    ]);
    seed['aiTissuePercentages'] = {
      'granulation_red_percent': 62,
      'slough_yellow_percent': 28,
      'necrosis_black_percent': 10,
    };
    seed['finalAreaCm2'] = 12.5;
    seed['finalLengthCm'] = 4.2;
    seed['finalWidthCm'] = 3.1;
    seed['finalPolygonJson'] = seed['aiPolygonJson'];
    seed['confirmedWithoutChange'] = true;
    seed['nrsPainScore'] = 3;
    seed['vssVascularity'] = 2;
    seed['vssPigmentation'] = 2;
    seed['vssPliability'] = 1;
    seed['vssHeight'] = 1;
    seed['vssTotal'] = 6;
    seed['signedBy'] = 'demo-physician-01';
    seed['signedAt'] = now;
    seed['signOffMethod'] = 'pin';
    seed['notes'] = '演示数据：一次已锁定的评估记录';
    seed['protocolId'] = 'pr1';
    seed['centerId'] = 'c1';
    seed['deviceId'] = 'd1';
    seed['deviceUsageLogId'] = 'du1';

    // GCP W3.1 — 把演示用照片源数据挂在 seed 上, 让评估详情页
    // "下载原始"按钮有 JSON 可展示.
    seed['photoMetadataSnapshot'] = {
      'cosKey': '/original/${seed['id']}/2026-08-01T09-30-00Z.jpg',
      'thumbKey': '/thumb/${seed['id']}/2026-08-01T09-30-00Z.jpg',
      'sha256':
          'a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90',
      'exifJson':
          '{"Image Make":"Apple","Image Model":"iPhone 16 Pro","Image Software":"0.1.0","EXIF DateTimeOriginal":"2026:08:01 09:30:00","EXIF ExposureTime":"1/60","EXIF FNumber":"1.8"}',
      'deviceFingerprint': 'ios-iphonesimulator-18.4-demo',
      'deviceModel': 'iPhone Simulator',
      'osVersion': 'iOS 18.4 (Simulator)',
      'appVersion': '0.1.0',
      'capturedAt': '2026-08-01T01:30:00.000Z',
      'capturedTimeSource': 'exif_original',
      'capturedBy': 'demo-nurse-01',
      'capturedByRole': 'CRC',
      'qcCardId': 'QC-CARD-DEMO-001',
      'qcPassed': true,
      'cardDimensionCm': 2.0,
      'gpsStripped': true,
      'mimeType': 'image/jpeg',
      'bytes': 245678,
      'uploadedAt': '2026-08-01T01:30:05.000Z',
      'subjectCode': _patients['p1']?['subjectCode'],
    };

    // GCP W3.2 — CRF 字段三态（ND/UN/NA），seed 给演示版两态各一项.
    seed['concomitantMedications'] = [
      {'triState': 'NA', 'note': '本次评估无合并用药'},
    ];
    seed['concomitantDiseases'] = [
      {'triState': 'NA', 'note': '本次评估无合并疾病'},
    ];
    seed['aeRefs'] = [
      {'triState': 'NA', 'note': '本次评估无不良事件'},
    ];
    seed['crfCompletionDeclaredAt'] = now;
    seed['crfCompletedBy'] = 'demo-physician-01';
    seed['crfCompletedByName'] = '演示医师';

    // One CREATE audit entry so the chain starts somewhere visible.
    AuditLogger.I.record(
      tableName: 'patient',
      recordId: 'p1',
      opType: AuditOpType.create,
      afterValue: {'subjectCode': _patients['p1']!['subjectCode']},
      ctx: _demoCtx,
      reason: 'demo seed',
    );

    _seedProtocolsCentersDevices(now);
  }

  /// W2 seed — 1 个方案 + 2 个中心 + 5 个器械 + 3 例分配 + 2 条器械使用台账.
  void _seedProtocolsCentersDevices(String now) {
    if (_protocols.isNotEmpty) return;

    // 1 个试验方案（开展中，主中心覆盖所有 demo 受试者）
    _protocols['pr1'] = {
      'id': 'pr1',
      'code': 'WOUND-2026-A',
      'name': '新型创面敷料 RCT',
      'version': '1.0',
      'sponsor': '山东笃行临床研究院',
      'phase': 'pivotal',
      'startDate': '2026-07-01T00:00:00Z',
      'endDate': null,
      'status': 'active',
      'summary': '比较新型敷料 vs 标准凡士林纱布对慢性创面愈合的影响',
      'createdAt': now,
      'updatedAt': now,
    };

    // 2 个研究中心
    _centers['c1'] = {
      'id': 'c1',
      'code': 'SD-HOSP-001',
      'name': '山东大学齐鲁医院',
      'department': '烧伤整形科',
      'address': '济南市文化西路 107 号',
      'irbNumber': 'SDQL-IRB-2026-018',
      'irbApprovalDate': '2026-06-15T00:00:00Z',
      'leadPiId': 'demo-physician-01',
      'leadPiName': '王立明',
      'createdAt': now,
      'updatedAt': now,
    };
    _centers['c2'] = {
      'id': 'c2',
      'code': 'SD-HOSP-002',
      'name': '山东省立医院',
      'department': '创面修复中心',
      'address': '济南市经五路 324 号',
      'irbNumber': 'SDSPH-IRB-2026-042',
      'irbApprovalDate': '2026-07-01T00:00:00Z',
      'leadPiId': null,
      'leadPiName': '待指派',
      'createdAt': now,
      'updatedAt': now,
    };

    // 3 例分配：方案 pr1 已激活至 c1 + c2 + 一个虚拟分中心
    _allocations['al1'] = {
      'id': 'al1',
      'protocolId': 'pr1',
      'centerId': 'c1',
      'irbApprovalDate': '2026-06-15T00:00:00Z',
      'irbDocumentPath': null,
      'piId': 'demo-physician-01',
      'piName': '王立明',
      'activatedAt': '2026-07-01T08:00:00Z',
      'status': 'active',
      'createdAt': now,
      'updatedAt': now,
    };
    _allocations['al2'] = {
      'id': 'al2',
      'protocolId': 'pr1',
      'centerId': 'c2',
      'irbApprovalDate': '2026-07-01T00:00:00Z',
      'irbDocumentPath': null,
      'piId': null,
      'piName': '待指派',
      'activatedAt': null,
      'status': 'pending',
      'createdAt': now,
      'updatedAt': now,
    };

    // 5 个试用器械 — 2 个已分配给 demo 患者，3 个在仓库
    _devices['d1'] = {
      'id': 'd1',
      'deviceType': '创面敷料',
      'modelName': 'HydroFlex-200',
      'manufacturer': '笃行医疗科技',
      'lotNumber': 'LOT-2026-A01',
      'serialNumber': 'SN-001001',
      'manufactureDate': '2026-05-01T00:00:00Z',
      'expiryDate': '2027-05-01T00:00:00Z',
      'qcPassedAt': '2026-05-10',
      'currentLocation': 'center',
      'currentCenterId': 'c1',
      'protocolId': 'pr1',
      'status': 'in-use',
      'createdAt': now,
      'updatedAt': now,
    };
    _devices['d2'] = {
      'id': 'd2',
      'deviceType': '创面敷料',
      'modelName': 'HydroFlex-200',
      'manufacturer': '笃行医疗科技',
      'lotNumber': 'LOT-2026-A01',
      'serialNumber': 'SN-001002',
      'manufactureDate': '2026-05-01T00:00:00Z',
      'expiryDate': '2027-05-01T00:00:00Z',
      'qcPassedAt': '2026-05-10',
      'currentLocation': 'center',
      'currentCenterId': 'c1',
      'protocolId': 'pr1',
      'status': 'in-use',
      'createdAt': now,
      'updatedAt': now,
    };
    _devices['d3'] = {
      'id': 'd3',
      'deviceType': '创面敷料',
      'modelName': 'HydroFlex-200',
      'manufacturer': '笃行医疗科技',
      'lotNumber': 'LOT-2026-A02',
      'serialNumber': 'SN-002001',
      'manufactureDate': '2026-05-15T00:00:00Z',
      'expiryDate': '2027-05-15T00:00:00Z',
      'qcPassedAt': '2026-05-22',
      'currentLocation': 'warehouse',
      'currentCenterId': 'c1',
      'protocolId': 'pr1',
      'status': 'sealed',
      'createdAt': now,
      'updatedAt': now,
    };
    _devices['d4'] = {
      'id': 'd4',
      'deviceType': '创面敷料',
      'modelName': 'HydroFlex-200',
      'manufacturer': '笃行医疗科技',
      'lotNumber': 'LOT-2026-A02',
      'serialNumber': 'SN-002002',
      'manufactureDate': '2026-05-15T00:00:00Z',
      'expiryDate': '2027-05-15T00:00:00Z',
      'qcPassedAt': '2026-05-22',
      'currentLocation': 'warehouse',
      'currentCenterId': 'c1',
      'protocolId': 'pr1',
      'status': 'sealed',
      'createdAt': now,
      'updatedAt': now,
    };
    _devices['d5'] = {
      'id': 'd5',
      'deviceType': '创面敷料',
      'modelName': 'HydroFlex-200',
      'manufacturer': '笃行医疗科技',
      'lotNumber': 'LOT-2026-A03',
      'serialNumber': 'SN-003001',
      'manufactureDate': '2026-06-01T00:00:00Z',
      'expiryDate': '2027-06-01T00:00:00Z',
      'qcPassedAt': '2026-06-08',
      'currentLocation': 'warehouse',
      'currentCenterId': 'c1',
      'protocolId': 'pr1',
      'status': 'sealed',
      'createdAt': now,
      'updatedAt': now,
    };

    // 2 条使用台账（demo 张伟 / 李秀英）
    _deviceUsageLogs['du1'] = {
      'id': 'du1',
      'deviceId': 'd1',
      'centerId': 'c1',
      'patientId': 'p1',
      'protocolId': 'pr1',
      'operatorId': 'demo-nurse-01',
      'operatorName': '演示护士',
      'allocatedAt': '2026-08-01T09:30:00Z',
      'returnedAt': null,
      'returnCondition': null,
      'disposalReason': null,
      'notes': '首次入组分配',
      'createdAt': now,
      'updatedAt': now,
    };
    _deviceUsageLogs['du2'] = {
      'id': 'du2',
      'deviceId': 'd2',
      'centerId': 'c1',
      'patientId': 'p2',
      'protocolId': 'pr1',
      'operatorId': 'demo-nurse-01',
      'operatorName': '演示护士',
      'allocatedAt': '2026-07-20T10:00:00Z',
      'returnedAt': null,
      'returnCondition': null,
      'disposalReason': null,
      'notes': null,
      'createdAt': now,
      'updatedAt': now,
    };

    // 把方案/中心/器械挂到 demo 评估上, 让趋势图能拉到正确的多中心数据
    _assessments.forEach((aid, a) {
      if (aid == 'asmt_demo_1') {
        a['protocolId'] = 'pr1';
        a['centerId'] = 'c1';
        a['deviceId'] = 'd1';
        a['deviceUsageLogId'] = 'du1';
      }
    });
  }

  Map<String, dynamic> _assess(
      String woundId, String patientId, String clinicianId) {
    final id = _newId('asmt');
    final now = _nowIso();
    final a = <String, dynamic>{
      'id': id,
      'patientId': patientId,
      'woundId': woundId,
      'clinicianId': clinicianId,
      'clinicianName': '演示护士',
      'status': 'draft',
      'createdAt': now,
      'updatedAt': now,
    };
    _assessments[id] = a;
    return a;
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final path = options.path;
    final method = options.method.toUpperCase();

    Response<dynamic> ok(dynamic data, {int statusCode = 200}) =>
        Response<dynamic>(
            requestOptions: options, data: data, statusCode: statusCode);

    try {
      // ---------- auth ----------
      if (method == 'POST' && path == '/auth/login') {
        final body = (options.data as Map?)?.cast<String, dynamic>() ?? {};
        final username = (body['username'] as String? ?? '').trim();
        if (username.isEmpty) {
          return handler.reject(DioException(
              requestOptions: options,
              response: ok({'message': '用户名不能为空'}, statusCode: 400)));
        }
        final role = _roleForUsername(username);
        final user = User(
          id: 'u_${username.toLowerCase()}',
          username: username,
          displayName: _displayNameFor(username, role),
          role: role,
          centerIds: const ['c1', 'c2'],
          permissions: RolePermissionMatrix.permissionsOf(role),
        );
        // 更新 demo ctx + 缓存 user
        _currentUser = user;
        _demoCtx = AuditContext(
          operatorId: user.id,
          operatorName: user.displayName,
          operatorRole: role.name,
          operatorIp: '127.0.0.1',
          deviceFingerprint: 'sim-iphone16pro',
          appVersion: '0.1.0',
        );
        return handler.resolve(ok({
          'token': 'demo-token-${role.name}-${DateTime.now().millisecondsSinceEpoch}',
          'user': user.toJson(),
          'userId': user.id,
          'displayName': user.displayName,
          'role': role.name,
        }));
      }
      if (method == 'GET' && path == '/auth/me') {
        final u = _currentUser;
        if (u == null) {
          return handler.reject(DioException(
              requestOptions: options,
              response: ok({'message': '未登录'}, statusCode: 401)));
        }
        return handler.resolve(ok(u.toJson()));
      }
      // 切换演示角色（V1 demo 专属，绕过 /auth/login 重新登录）
      if (method == 'POST' && path == '/auth/switch-demo-role') {
        final body = (options.data as Map?)?.cast<String, dynamic>() ?? {};
        final roleStr = body['role'] as String?;
        final newRole = UserRole.tryParse(roleStr);
        if (newRole == null) {
          return handler.reject(DioException(
              requestOptions: options,
              response: ok({'message': '未知角色: $roleStr'}, statusCode: 400)));
        }
        final oldRole = _currentUser?.role;
        final newUser = (_currentUser ??
                User(
                  id: 'demo',
                  username: 'demo',
                  displayName: '演示用户',
                  role: newRole,
                ))
            .copyWith(
          role: newRole,
          displayName: _displayNameFor('demo', newRole),
          permissions: RolePermissionMatrix.permissionsOf(newRole),
        );
        _currentUser = newUser;
        _demoCtx = AuditContext(
          operatorId: newUser.id,
          operatorName: newUser.displayName,
          operatorRole: newRole.name,
          operatorIp: '127.0.0.1',
          deviceFingerprint: 'sim-iphone16pro',
          appVersion: '0.1.0',
        );
        // 审计：角色切换
        AuditLogger.I.record(
          tableName: 'user',
          recordId: newUser.id,
          opType: AuditOpType.update,
          fieldName: 'role',
          beforeValue: oldRole?.name,
          afterValue: newRole.name,
          ctx: _demoCtx,
          reason: 'V1 demo 切换演示角色',
        );
        return handler.resolve(ok({
          'user': newUser.toJson(),
          'role': newRole.name,
        }));
      }
      if (method == 'POST' &&
          (path == '/auth/change-pin' || path.startsWith('/auth/signature-pin'))) {
        return handler.resolve(ok({'success': true, 'message': 'OK'}));
      }

      // ---------- patients ----------
      if (method == 'GET' && path == '/patients') {
        _ensureSeeded();
        return handler.resolve(ok({
          'content': _patients.values
              .map((p) => _patientForClient(p, _demoCtx.operatorRole ?? ''))
              .toList(),
          'totalElements': _patients.length,
        }));
      }
      if (method == 'POST' && path == '/patients') {
        // W4.3 — 角色守门：CRC/PI/SubI/Admin 才能新建受试者
        final perm = _checkPermission(options, Permission.patientCreate);
        if (perm != null) {
          return handler.reject(
              DioException(requestOptions: options, response: perm));
        }
        _ensureSeeded();
        final body = (options.data as Map?)?.cast<String, dynamic>() ?? {};
        final now = _nowIso();
        final realName = body['name'] as String? ?? '新患者';
        final subjectCode = _nextSubjectCode(realName);
        final id = _newId('p');
        final p = <String, dynamic>{
          'id': id,
          'facilityId': body['facilityId'] ?? 'f1',
          'subjectCode': subjectCode,
          // ignore: deprecated_member_use_from_same_package
          'patientCode': body['patientCode'] ?? subjectCode,
          'name': realName,
          'medicalRecordNo': body['medicalRecordNo'] ??
              'MRN-${DateTime.now().year}-${1000 + _patients.length}',
          'dateOfBirth': body['dateOfBirth'],
          'gender': body['gender'],
          'createdAt': now,
          'updatedAt': now,
        };
        _patients[id] = p;
        _identityMap[subjectCode] = {
          'subjectCode': subjectCode,
          'realName': realName,
          'medicalRecordNo': p['medicalRecordNo'],
          'encryptedBy': 'demo',
          'createdAt': now,
        };
        AuditLogger.I.record(
          tableName: 'patient',
          recordId: id,
          opType: AuditOpType.create,
          fieldName: 'subjectCode',
          afterValue: subjectCode,
          ctx: _demoCtx,
          reason: '新建受试者',
        );
        return handler.resolve(
            ok(_patientForClient(p, _demoCtx.operatorRole ?? ''),
                statusCode: 201));
      }
      final patientIdMatch = RegExp(r'^/patients/([^/]+)$').firstMatch(path);
      if (patientIdMatch != null) {
        final id = patientIdMatch.group(1)!;
        if (method == 'GET') {
          final p = _patients[id];
          return p == null
              ? handler.reject(DioException(
                  requestOptions: options,
                  response: ok({'message': 'Patient not found'},
                      statusCode: 404)))
              : handler.resolve(
                  ok(_patientForClient(p, _demoCtx.operatorRole ?? '')));
        }
        if (method == 'PUT') {
          final body =
              (options.data as Map?)?.cast<String, dynamic>() ?? {};
          final p = _patients[id];
          if (p == null) {
            return handler.reject(DioException(
                requestOptions: options,
                response: ok({'message': 'Patient not found'},
                    statusCode: 404)));
          }
          // Record each touched field as its own audit row.
          for (final entry in body.entries) {
            final field = entry.key;
            final before = p[field];
            final after = entry.value;
            if (before == after) continue;
            AuditLogger.I.record(
              tableName: 'patient',
              recordId: id,
              opType: AuditOpType.update,
              fieldName: field,
              beforeValue: before,
              afterValue: after,
              ctx: _demoCtx,
              reason: body['reason'] as String? ?? '修改',
            );
          }
          final merged = {...p, ...body, 'id': id, 'updatedAt': _nowIso()};
          _patients[id] = merged;
          return handler.resolve(
              ok(_patientForClient(merged, _demoCtx.operatorRole ?? '')));
        }
      }

      // Identity access — only PI / SubI / Admin may read.
      final identityMatch =
          RegExp(r'^/patients/([^/]+)/identity$').firstMatch(path);
      if (identityMatch != null && method == 'GET') {
        final pid = identityMatch.group(1)!;
        final p = _patients[pid];
        if (p == null) {
          return handler.reject(DioException(
              requestOptions: options,
              response: ok({'message': 'Patient not found'},
                  statusCode: 404)));
        }
        final role = _demoCtx.operatorRole ?? '';
        final canSee = role == 'PI' || role == 'SubI' || role == 'Admin';
        if (!canSee) {
          AuditLogger.I.record(
            tableName: 'patient_identity',
            recordId: pid,
            opType: AuditOpType.accessDenied,
            afterValue: {'reason': 'role=$role not allowed'},
            ctx: _demoCtx,
            reason: '尝试访问真名映射',
          );
          return handler.reject(DioException(
            requestOptions: options,
            response: ok({'message': 'Forbidden'}, statusCode: 403),
          ));
        }
        final idRec = _identityMap[p['subjectCode']];
        AuditLogger.I.record(
          tableName: 'patient_identity',
          recordId: pid,
          opType: AuditOpType.identityAccess,
          afterValue: {'subjectCode': p['subjectCode']},
          ctx: _demoCtx,
          reason: '查看真名映射',
        );
        return handler.resolve(ok(idRec));
      }

      // ---------- W2 试验方案 / 中心 / 试用器械 / 台账 ----------
      // ---------- consents (W4.1) ----------
      if (method == 'POST' && path == '/consents') {
        // 守门：consent:sign 权限
        final perm = _checkPermission(options, Permission.consentSign);
        if (perm != null) {
          return handler.reject(
              DioException(requestOptions: options, response: perm));
        }
        final body = (options.data as Map?)?.cast<String, dynamic>() ?? {};
        final patientId = body['patientId'] as String?;
        if (patientId == null || patientId.isEmpty) {
          return handler.reject(DioException(
              requestOptions: options,
              response: ok({'message': 'patientId 必填'}, statusCode: 400)));
        }
        // 校验患者存在
        if (!_patients.values.any((p) => p['id'] == patientId)) {
          return handler.reject(DioException(
              requestOptions: options,
              response: ok({'message': '患者不存在'}, statusCode: 404)));
        }
        final mode = ConsentMode.tryParse(body['mode'] as String?) ??
            ConsentMode.PAPER_PHOTO;
        final id = _newId('csnt');
        final now = _nowIso();
        final consent = <String, dynamic>{
          'id': id,
          'patientId': patientId,
          'protocolId': body['protocolId'] as String? ?? 'pr1',
          'centerId': body['centerId'] as String?,
          'version': body['version'] as String? ?? '1.0',
          'mode': mode.name,
          'signedAt': now,
          'signedBy': body['signedBy'] as String? ?? _demoCtx.operatorId,
          'signedByName': body['signedByName'] as String? ?? _demoCtx.operatorName,
          'pdfPath': body['pdfPath'],
          'signaturePath': body['signaturePath'],
          'signatureStrokeJson': body['signatureStrokeJson'],
          'deviceFingerprint':
              body['deviceFingerprint'] as String? ?? _demoCtx.deviceFingerprint,
          'operatorIp': body['operatorIp'] as String? ?? _demoCtx.operatorIp,
          'signedPaperPath': body['signedPaperPath'],
          'paperSignedDate': body['paperSignedDate'] as String?,
          'witnessName': body['witnessName'] as String?,
          'withdrawnAt': null,
          'withdrawnBy': null,
          'withdrawReason': null,
          // B 通道默认未审核
          'reviewedByPi': mode == ConsentMode.E_CONSENT,
          'reviewedBy': mode == ConsentMode.E_CONSENT
              ? _demoCtx.operatorId
              : null,
          'reviewedAt': mode == ConsentMode.E_CONSENT ? now : null,
          'reviewNote': null,
          'createdAt': now,
          'updatedAt': now,
        };
        _consents[id] = consent;
        // 审计：A 通道 sign / B 通道 sign (待审核)
        AuditLogger.I.record(
          tableName: 'consent',
          recordId: id,
          opType: AuditOpType.consentSign,
          fieldName: 'mode',
          afterValue: mode.name,
          ctx: _demoCtx,
          reason: mode == ConsentMode.E_CONSENT
              ? 'A 通道 eConsent 签署'
              : 'B 通道纸质件拍照存档',
        );
        return handler.resolve(ok(consent, statusCode: 201));
      }
      // 撤回
      final withdrawMatch =
          RegExp(r'^/consents/([^/]+)/withdraw$').firstMatch(path);
      if (withdrawMatch != null && method == 'POST') {
        final perm = _checkPermission(options, Permission.consentWithdraw);
        if (perm != null) {
          return handler.reject(
              DioException(requestOptions: options, response: perm));
        }
        final id = withdrawMatch.group(1)!;
        final c = _consents[id];
        if (c == null) {
          return handler.reject(DioException(
              requestOptions: options,
              response: ok({'message': 'consent 不存在'}, statusCode: 404)));
        }
        if (c['withdrawnAt'] != null) {
          return handler.reject(DioException(
              requestOptions: options,
              response: ok({'message': '已撤回'}, statusCode: 409)));
        }
        final body =
            (options.data as Map?)?.cast<String, dynamic>() ?? {};
        c['withdrawnAt'] = _nowIso();
        c['withdrawnBy'] = _demoCtx.operatorId;
        c['withdrawReason'] = body['reason'] as String? ?? '（未填）';
        c['updatedAt'] = c['withdrawnAt'];
        AuditLogger.I.record(
          tableName: 'consent',
          recordId: id,
          opType: AuditOpType.consentWithdraw,
          fieldName: 'withdrawnAt',
          beforeValue: null,
          afterValue: c['withdrawnAt'],
          ctx: _demoCtx,
          reason: c['withdrawReason'] as String,
        );
        return handler.resolve(ok(c));
      }
      // B 通道 PI 审核
      final reviewMatch =
          RegExp(r'^/consents/([^/]+)/review$').firstMatch(path);
      if (reviewMatch != null && method == 'POST') {
        final perm = _checkPermission(options, Permission.consentSign);
        if (perm != null) {
          return handler.reject(
              DioException(requestOptions: options, response: perm));
        }
        final id = reviewMatch.group(1)!;
        final c = _consents[id];
        if (c == null) {
          return handler.reject(DioException(
              requestOptions: options,
              response: ok({'message': 'consent 不存在'}, statusCode: 404)));
        }
        if (c['mode'] != ConsentMode.PAPER_PHOTO.name) {
          return handler.reject(DioException(
              requestOptions: options,
              response: ok(
                  {'message': 'A 通道 eConsent 无需 PI 复核'},
                  statusCode: 400)));
        }
        final body =
            (options.data as Map?)?.cast<String, dynamic>() ?? {};
        c['reviewedByPi'] = true;
        c['reviewedBy'] = _demoCtx.operatorId;
        c['reviewedAt'] = _nowIso();
        c['reviewNote'] = body['note'] as String? ?? '';
        c['updatedAt'] = c['reviewedAt'];
        AuditLogger.I.record(
          tableName: 'consent',
          recordId: id,
          opType: AuditOpType.update,
          fieldName: 'reviewedByPi',
          beforeValue: false,
          afterValue: true,
          ctx: _demoCtx,
          reason: 'B 通道纸质件 PI 审核通过',
        );
        return handler.resolve(ok(c));
      }
      // 查某患者所有 consent
      final patientConsentMatch =
          RegExp(r'^/consents/patient/([^/]+)$').firstMatch(path);
      if (patientConsentMatch != null && method == 'GET') {
        final perm = _checkPermission(options, Permission.auditRead);
        if (perm != null) {
          return handler.reject(
              DioException(requestOptions: options, response: perm));
        }
        final pid = patientConsentMatch.group(1)!;
        final list = _consents.values
            .where((c) => c['patientId'] == pid)
            .toList()
          ..sort((a, b) =>
              (b['signedAt'] as String).compareTo(a['signedAt'] as String));
        return handler.resolve(ok({
          'data': list,
          'totalElements': list.length,
        }));
      }
      // 切换中心 consentMode
      final centerModeMatch =
          RegExp(r'^/centers/([^/]+)/consent-mode$').firstMatch(path);
      if (centerModeMatch != null && method == 'PUT') {
        final perm = _checkPermission(options, Permission.consentConfigure);
        if (perm != null) {
          return handler.reject(
              DioException(requestOptions: options, response: perm));
        }
        final cid = centerModeMatch.group(1)!;
        final body =
            (options.data as Map?)?.cast<String, dynamic>() ?? {};
        final newMode =
            ConsentMode.tryParse(body['mode'] as String?);
        if (newMode == null) {
          return handler.reject(DioException(
              requestOptions: options,
              response: ok({'message': 'mode 必填'}, statusCode: 400)));
        }
        final oldMode = _centers[cid]?['consentMode'];
        _centers[cid]?['consentMode'] = newMode.name;
        _centers[cid]?['consentModeSetAt'] = _nowIso();
        _centers[cid]?['consentModeSetBy'] = _demoCtx.operatorId;
        _centers[cid]?['updatedAt'] = _centers[cid]?['consentModeSetAt'];
        AuditLogger.I.record(
          tableName: 'center',
          recordId: cid,
          opType: AuditOpType.update,
          fieldName: 'consentMode',
          beforeValue: oldMode,
          afterValue: newMode.name,
          ctx: _demoCtx,
          reason: '机构设置：中心 consentMode 切换',
        );
        return handler.resolve(ok(_centers[cid]));
      }
      // ---------- 原有 trial 端点 ----------
      if (method == 'GET' && path == '/protocols') {
        _ensureSeeded();
        return handler.resolve(ok({
          'data': _protocols.values.toList(),
          'totalElements': _protocols.length,
        }));
      }
      if (method == 'GET' && path == '/centers') {
        _ensureSeeded();
        return handler.resolve(ok({
          'data': _centers.values.toList(),
          'totalElements': _centers.length,
        }));
      }
      if (method == 'GET' && path == '/devices') {
        _ensureSeeded();
        final status = options.queryParameters['status'] as String?;
        final centerId = options.queryParameters['centerId'] as String?;
        final list = _devices.values.where((d) {
          if (status != null && d['status'] != status) return false;
          if (centerId != null && d['currentCenterId'] != centerId) {
            return false;
          }
          return true;
        }).toList();
        return handler.resolve(ok({
          'data': list,
          'totalElements': list.length,
        }));
      }
      final protocolCentersMatch =
          RegExp(r'^/protocols/([^/]+)/centers$').firstMatch(path);
      if (protocolCentersMatch != null && method == 'GET') {
        _ensureSeeded();
        final prid = protocolCentersMatch.group(1)!;
        final list = _allocations.values
            .where((a) => a['protocolId'] == prid)
            .toList();
        return handler.resolve(ok({
          'data': list,
          'totalElements': list.length,
        }));
      }
      if (method == 'GET' && path == '/device-usage-logs') {
        _ensureSeeded();
        final deviceId = options.queryParameters['deviceId'] as String?;
        final patientId = options.queryParameters['patientId'] as String?;
        final protocolId = options.queryParameters['protocolId'] as String?;
        final list = _deviceUsageLogs.values.where((l) {
          if (deviceId != null && l['deviceId'] != deviceId) return false;
          if (patientId != null && l['patientId'] != patientId) return false;
          if (protocolId != null && l['protocolId'] != protocolId) {
            return false;
          }
          return true;
        }).toList();
        return handler.resolve(ok({
          'data': list,
          'totalElements': list.length,
        }));
      }

      // Audit log read.
      if (method == 'GET' && path == '/audit-log') {
        final table = (options.queryParameters['table'] as String?) ?? '';
        final recordId =
            (options.queryParameters['recordId'] as String?) ?? '';
        final list = (table.isEmpty || recordId.isEmpty)
            ? AuditLogger.I.entries
            : AuditLogger.I.entriesFor(
                tableName: table, recordId: recordId);
        return handler.resolve(ok({
          'content': list.map((e) => e.toJson()).toList(),
          'totalElements': list.length,
          'chainValid': AuditLogger.I.verifyChain() == -1,
        }));
      }

      // ---------- wounds ----------
      final patientWoundsMatch =
          RegExp(r'^/patients/([^/]+)/wounds$').firstMatch(path);
      if (patientWoundsMatch != null) {
        final pid = patientWoundsMatch.group(1)!;
        if (method == 'GET') {
          _ensureSeeded();
          return handler.resolve(ok(_wounds.values
              .where((w) => w['patientId'] == pid)
              .toList()));
        }
        if (method == 'POST') {
          final body =
              (options.data as Map?)?.cast<String, dynamic>() ?? {};
          final now = _nowIso();
          final id = _newId('w');
          final w = <String, dynamic>{
            'id': id,
            'patientId': pid,
            'anatomicalLocation':
                body['anatomicalLocation'] ?? '未指定部位',
            'woundType': body['woundType'],
            'etiology': body['etiology'],
            'onsetDate': body['onsetDate'] ?? now,
            'createdAt': now,
            'updatedAt': now,
          };
          _wounds[id] = w;
          AuditLogger.I.record(
            tableName: 'wound',
            recordId: id,
            opType: AuditOpType.create,
            fieldName: 'anatomicalLocation',
            afterValue: w['anatomicalLocation'],
            ctx: _demoCtx,
            reason: '新建创面',
          );
          return handler.resolve(ok(w, statusCode: 201));
        }
      }
      final woundMatch = RegExp(r'^/wounds/([^/]+)$').firstMatch(path);
      if (woundMatch != null) {
        final id = woundMatch.group(1)!;
        if (method == 'GET') {
          final w = _wounds[id];
          return w == null
              ? handler.reject(DioException(
                  requestOptions: options,
                  response: ok({'message': 'Wound not found'},
                      statusCode: 404)))
              : handler.resolve(ok(w));
        }
        if (method == 'PUT') {
          final body =
              (options.data as Map?)?.cast<String, dynamic>() ?? {};
          final w = _wounds[id];
          if (w == null) {
            return handler.reject(DioException(
                requestOptions: options,
                response: ok({'message': 'Wound not found'},
                    statusCode: 404)));
          }
          for (final entry in body.entries) {
            final field = entry.key;
            final before = w[field];
            final after = entry.value;
            if (before == after) continue;
            AuditLogger.I.record(
              tableName: 'wound',
              recordId: id,
              opType: AuditOpType.update,
              fieldName: field,
              beforeValue: before,
              afterValue: after,
              ctx: _demoCtx,
              reason: body['reason'] as String? ?? '修改',
            );
          }
          final merged = {...w, ...body, 'id': id, 'updatedAt': _nowIso()};
          _wounds[id] = merged;
          return handler.resolve(ok(merged));
        }
      }

      // ---------- assessments ----------
      final woundAssessmentsMatch =
          RegExp(r'^/wounds/([^/]+)/assessments$').firstMatch(path);
      if (woundAssessmentsMatch != null && method == 'GET') {
        _ensureSeeded();
        final wid = woundAssessmentsMatch.group(1)!;
        return handler.resolve(ok(
          _assessments.values.where((a) => a['woundId'] == wid).toList(),
        ));
      }

      if (method == 'POST' && path == '/assessments') {
        _ensureSeeded();
        final body =
            (options.data as Map?)?.cast<String, dynamic>() ?? {};
        final a = _assess(
          body['woundId'] as String? ?? 'w1',
          body['patientId'] as String? ?? 'p1',
          body['clinicianId'] as String? ?? 'demo-nurse-01',
        );
        a['clinicianName'] = body['clinicianName'];
        a['notes'] = body['notes'];
        final createdAtFromBody = body['createdAt'];
        if (createdAtFromBody is String) {
          final parsed = DateTime.tryParse(createdAtFromBody);
          if (parsed != null) {
            a['createdAt'] = parsed.toUtc().toIso8601String();
          }
        }
        AuditLogger.I.record(
          tableName: 'assessment',
          recordId: a['id'],
          opType: AuditOpType.create,
          fieldName: 'woundId',
          afterValue: a['woundId'],
          ctx: _demoCtx,
          reason: '新建评估',
        );
        return handler.resolve(ok(a, statusCode: 201));
      }

      final assessmentMatch =
          RegExp(r'^/assessments/([^/]+)$').firstMatch(path);
      if (assessmentMatch != null && method == 'GET') {
        final a = _assessments[assessmentMatch.group(1)!];
        return a == null
            ? handler.reject(DioException(
                requestOptions: options,
                response: ok({'message': 'Assessment not found'},
                    statusCode: 404)))
            : handler.resolve(ok(a));
      }

      final assessmentActionMatch =
          RegExp(r'^/assessments/([^/]+)/([a-z-]+)$').firstMatch(path);
      if (assessmentActionMatch != null) {
        final id = assessmentActionMatch.group(1)!;
        final action = assessmentActionMatch.group(2)!;
        final a = _assessments[id];
        if (a == null) {
          return handler.reject(DioException(
              requestOptions: options,
              response: ok({'message': 'Assessment not found'},
                  statusCode: 404)));
        }
        switch (action) {
          case 'analyze':
            a['aiAreaCm2'] = 9.8;
            a['aiLengthCm'] = 3.9;
            a['aiWidthCm'] = 2.7;
            final imgBody =
                (options.data as Map?)?.cast<String, dynamic>() ?? {};
            final imageUrl = imgBody['imageUrl'] as String?;
            if (imageUrl != null && !imageUrl.startsWith('demo://')) {
              a['photoPath'] = imageUrl;
            }
            a['aiPolygonJson'] = jsonEncode([
              {'x': 450, 'y': 355},
              {'x': 615, 'y': 428},
              {'x': 690, 'y': 600},
              {'x': 618, 'y': 770},
              {'x': 450, 'y': 845},
              {'x': 282, 'y': 770},
              {'x': 210, 'y': 600},
              {'x': 283, 'y': 425},
            ]);
            a['aiTissuePercentages'] = {
              'granulation_red_percent': 55,
              'slough_yellow_percent': 35,
              'necrosis_black_percent': 10,
            };
            a['updatedAt'] = _nowIso();
            AuditLogger.I.record(
              tableName: 'assessment',
              recordId: id,
              opType: AuditOpType.update,
              fieldName: 'aiAreaCm2',
              beforeValue: a['aiAreaCm2'],
              afterValue: 9.8,
              ctx: _demoCtx,
              reason: 'AI 测量完成',
            );
            return handler.resolve(ok(a));
          case 'confirm':
            final body =
                (options.data as Map?)?.cast<String, dynamic>() ?? {};
            final reasonInBody = body['reason'] as String?;

            // GCP W3.2 — 三态校验（ND / UN / NA）。
            // 三个 CRF 字段必须为 list，且至少一个 item 必须
            // { triState: 'ND' | 'UN' | 'NA' }。
            const triStateFields = <String>[
              'concomitantMedications',
              'concomitantDiseases',
              'aeRefs',
            ];
            for (final f in triStateFields) {
              final v = body[f];
              if (v is! List) {
                return handler.reject(DioException(
                    requestOptions: options,
                    response: ok(
                      {'message': 'CRF 字段 $f 必须为数组（含 ND/UN/NA 三态）'},
                      statusCode: 400,
                    )));
              }
              final hasTriState = v.any((item) {
                if (item is! Map) return false;
                final ts = item['triState'];
                if (ts is! String) return false;
                return ts == 'ND' || ts == 'UN' || ts == 'NA';
              });
              if (!hasTriState) {
                return handler.reject(DioException(
                    requestOptions: options,
                    response: ok(
                      {
                        'message':
                            'CRF 字段 $f 必须包含 ND/UN/NA 三态中至少一项'
                      },
                      statusCode: 400,
                    )));
              }
            }

            // W3.1 — 若客户端把 cosKey / sha256 当作 photoMetadataSnapshot 提交过来，
            // 我们把它们"冻"到评估记录，后续只读不可改。
            if (body['photoMetadataSnapshot'] is Map) {
              a['photoMetadataSnapshot'] = body['photoMetadataSnapshot'];
            }

            for (final entry in body.entries) {
              if (entry.key == 'reason' ||
                  entry.key == 'photoMetadataSnapshot') {
                continue;
              }
              final field = entry.key;
              final before = a[field];
              final after = entry.value;
              if (before == after) continue;
              AuditLogger.I.record(
                tableName: 'assessment',
                recordId: id,
                opType: AuditOpType.update,
                fieldName: field,
                beforeValue: before,
                afterValue: after,
                ctx: _demoCtx,
                reason: reasonInBody ?? '临床数据确认',
              );
            }
            final merged = {...a, ...body, 'id': id, 'updatedAt': _nowIso()};
            _assessments[id] = merged;
            return handler.resolve(ok(merged));
          case 'submit':
            a['status'] = 'pendingSignature';
            a['updatedAt'] = _nowIso();
            AuditLogger.I.record(
              tableName: 'assessment',
              recordId: id,
              opType: AuditOpType.update,
              fieldName: 'status',
              beforeValue: 'draft',
              afterValue: 'pendingSignature',
              ctx: _demoCtx,
              reason: '评估提交审签',
            );
            return handler.resolve(ok(a));
          case 'lock':
            a['status'] = 'locked';
            a['signedBy'] = 'demo-physician-01';
            a['signedAt'] = _nowIso();
            a['signOffMethod'] = 'pin';
            a['updatedAt'] = _nowIso();
            AuditLogger.I.record(
              tableName: 'assessment',
              recordId: id,
              opType: AuditOpType.sign,
              fieldName: 'status',
              beforeValue: 'pendingSignature',
              afterValue: 'locked',
              ctx: _demoCtx,
              reason: '电子签名锁定',
            );
            return handler.resolve(ok(a));
        }
      }

      // ---------- images ----------
      final imagesMatch =
          RegExp(r'^/assessments/([^/]+)/images$').firstMatch(path);
      if (imagesMatch != null) {
        final id = imagesMatch.group(1)!;
        if (method == 'GET') {
          // 返回该评估的全部图片元数据
          final list = _photoMetadata.values
              .where((m) => m['assessmentId'] == id)
              .toList();
          return handler.resolve(ok({
            'content': list,
            'totalElements': list.length,
          }));
        }
        if (method == 'POST') {
          // GCP W3.1 — 接 multipart / JSON 混合 body，
          // metadata 字段是 JSON 字符串（V1 demo 简化路径）。
          final now = _nowIso();
          final imageId = _newId('img');

          // 解 body：可能是 FormData，也可能是 Map
          Map<String, dynamic> metaJson = const {};
          final rawData = options.data;
          if (rawData is FormData) {
            final metadataField = rawData.fields
                .firstWhere(
                  (e) => e.key == 'metadata',
                  orElse: () => const MapEntry('', ''),
                )
                .value;
            if (metadataField.isNotEmpty) {
              try {
                metaJson = Map<String, dynamic>.from(
                  jsonDecode(metadataField) as Map,
                );
              } catch (_) {/* 容错：保留空 */}
            }
          } else if (rawData is Map) {
            final m = rawData['metadata'];
            if (m is Map) metaJson = Map<String, dynamic>.from(m);
          }

          metaJson['imageId'] = imageId;
          metaJson['assessmentId'] = id;
          metaJson['uploadedAt'] = metaJson['uploadedAt'] ?? now;
          _photoMetadata[imageId] = Map<String, dynamic>.from(metaJson);

          // 同时挂到 assessment record（评估确认时再冻结）
          final a = _assessments[id];
          if (a != null) {
            a['photoMetadataSnapshot'] = Map<String, dynamic>.from(metaJson);
          }

          AuditLogger.I.record(
            tableName: 'assessment_image',
            recordId: imageId,
            opType: AuditOpType.create,
            fieldName: 'sha256',
            afterValue: metaJson['sha256'],
            ctx: _demoCtx,
            reason: '创面照片源数据落库（sha256=${(metaJson['sha256'] as String? ?? '').substring(0, metaJson['sha256'] is String ? 8 : 0)}…）',
          );

          return handler.resolve(ok({
            'id': imageId,
            'assessmentId': id,
            'imageType': 'woundCapture',
            'localPath': null,
            'remoteUrl': 'https://demo.example/images/$imageId.jpg',
            'capturedAt': now,
            'metadata': metaJson,
          }, statusCode: 201));
        }
      }

      // GCP W3.1 — 直接读评估冻结的照片元数据快照
      final photoMdMatch =
          RegExp(r'^/assessments/([^/]+)/photo-metadata$').firstMatch(path);
      if (photoMdMatch != null && method == 'GET') {
        final id = photoMdMatch.group(1)!;
        final a = _assessments[id];
        final snap = a?['photoMetadataSnapshot'];
        if (snap is Map) {
          return handler.resolve(ok({
            'assessmentId': id,
            'photoMetadata': snap,
          }));
        }
        return handler.reject(DioException(
            requestOptions: options,
            response: ok({'message': 'No photo metadata'}, statusCode: 404)));
      }

      // GCP W3.2 — CRF 完成声明（PI 必签，签后冻结临床字段）
      final crfCompleteMatch = RegExp(
              r'^/assessments/([^/]+)/declare-crf-complete$')
          .firstMatch(path);
      if (crfCompleteMatch != null && method == 'PATCH') {
        final id = crfCompleteMatch.group(1)!;
        final a = _assessments[id];
        if (a == null) {
          return handler.reject(DioException(
              requestOptions: options,
              response: ok({'message': 'Assessment not found'},
                  statusCode: 404)));
        }
        final body =
            (options.data as Map?)?.cast<String, dynamic>() ?? {};
        final pin = body['pin'] as String?;
        if (pin == null || pin.length < 4) {
          return handler.reject(DioException(
              requestOptions: options,
              response: ok({'message': 'CRF 完成声明需要 PIN 二次鉴别'},
                  statusCode: 400)));
        }
        final now = _nowIso();
        a['crfCompletionDeclaredAt'] = now;
        a['crfCompletedBy'] = body['operatorId'] ?? _demoCtx.operatorId;
        a['crfCompletedByName'] =
            body['operatorName'] ?? _demoCtx.operatorName;
        a['status'] = 'locked';
        a['signedBy'] = body['operatorId'] ?? _demoCtx.operatorId;
        a['signedAt'] = now;
        a['signOffMethod'] = 'pin';
        a['updatedAt'] = now;

        AuditLogger.I.record(
          tableName: 'assessment',
          recordId: id,
          opType: AuditOpType.sign,
          fieldName: 'crfCompletionDeclaredAt',
          beforeValue: null,
          afterValue: now,
          ctx: _demoCtx,
          reason: 'PI CRF 完成声明 + PIN 二次鉴别锁定',
        );
        _crfCompletionDeclarations.add({
          'id': 'decl_${DateTime.now().millisecondsSinceEpoch}',
          'assessmentId': id,
          'declaredAt': now,
          'declaredBy': a['crfCompletedBy'],
          'declaredByName': a['crfCompletedByName'],
          'pinFingerprint': sha256
              .convert(utf8.encode(pin))
              .toString()
              .substring(0, 12),
        });
        return handler.resolve(ok(a));
      }

      if (RegExp(r'^/assessment-images/').hasMatch(path) &&
          method == 'DELETE') {
        return handler.resolve(ok({'success': true}));
      }

      // Unknown endpoint -> 404 to surface integration mistakes early.
      return handler.reject(DioException(
        requestOptions: options,
        message: 'Demo backend: no handler for $method $path',
        response: ok({'message': 'Not found in demo backend'},
            statusCode: 404),
      ));
    } catch (e) {
      return handler.reject(DioException(
        requestOptions: options,
        message: 'Demo backend error: $e',
        error: e,
      ));
    }
  }
}