/// Trial protocol — the highest container of a clinical trial.
///
/// Each `Protocol` describes a sponsor's investigation version of a
/// device / drug; may be executed by one or more `Center`s.  Per
/// GCP §2022 第28号 第四章，protocols must be versioned, signed
/// off, and approved by an IRB before any subject can be enrolled.
class Protocol {
  final String id;
  final String code; // e.g. "WOUND-2026-A"
  final String name;
  final String version; // e.g. "1.0" / "1.1"
  final String sponsor;
  final String phase; // pilot / pivotal / post-market
  final DateTime startDate;
  final DateTime? endDate;
  final String status; // draft / active / suspended / closed
  final String? summary;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Protocol({
    required this.id,
    required this.code,
    required this.name,
    required this.version,
    required this.sponsor,
    required this.phase,
    required this.startDate,
    this.endDate,
    required this.status,
    this.summary,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Protocol.fromJson(Map<String, dynamic> json) {
    return Protocol(
      id: json['id'] as String,
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      version: json['version'] as String? ?? '1.0',
      sponsor: json['sponsor'] as String? ?? '',
      phase: json['phase'] as String? ?? 'pilot',
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: json['endDate'] != null
          ? DateTime.parse(json['endDate'] as String)
          : null,
      status: json['status'] as String? ?? 'draft',
      summary: json['summary'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'name': name,
        'version': version,
        'sponsor': sponsor,
        'phase': phase,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
        'status': status,
        'summary': summary,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  Protocol copyWith({
    String? id,
    String? code,
    String? name,
    String? version,
    String? sponsor,
    String? phase,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    String? summary,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Protocol(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      version: version ?? this.version,
      sponsor: sponsor ?? this.sponsor,
      phase: phase ?? this.phase,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      summary: summary ?? this.summary,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get displayLabel => '$code · $name ($version)';
  bool get isActive => status == 'active';
}
