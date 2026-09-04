/// Investigational device — a single physical unit of the trial product.
///
/// GCP §2022 第28号 第22条: investigational product storage,
/// dispensing and reconciliation must be tracked per unit. Each
/// `InvestigationalDevice` carries its lot number, serial, expiry,
/// and current location (warehouse / center / patient).
class InvestigationalDevice {
  final String id;
  final String deviceType; // 创面敷料 / 治疗仪 / 一次性耗材
  final String modelName;
  final String manufacturer;
  final String lotNumber;
  final String serialNumber;
  final DateTime manufactureDate;
  final DateTime? expiryDate;
  final String? qcPassedAt;
  final String currentLocation; // warehouse / center / patient / returned / disposed
  final String currentCenterId;
  final String? protocolId;
  final String status; // sealed / in-use / returned / damaged / disposed
  final DateTime createdAt;
  final DateTime updatedAt;

  const InvestigationalDevice({
    required this.id,
    required this.deviceType,
    required this.modelName,
    required this.manufacturer,
    required this.lotNumber,
    required this.serialNumber,
    required this.manufactureDate,
    this.expiryDate,
    this.qcPassedAt,
    required this.currentLocation,
    required this.currentCenterId,
    this.protocolId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory InvestigationalDevice.fromJson(Map<String, dynamic> json) {
    return InvestigationalDevice(
      id: json['id'] as String,
      deviceType: json['deviceType'] as String? ?? '',
      modelName: json['modelName'] as String? ?? '',
      manufacturer: json['manufacturer'] as String? ?? '',
      lotNumber: json['lotNumber'] as String? ?? '',
      serialNumber: json['serialNumber'] as String? ?? '',
      manufactureDate: DateTime.parse(json['manufactureDate'] as String),
      expiryDate: json['expiryDate'] != null
          ? DateTime.parse(json['expiryDate'] as String)
          : null,
      qcPassedAt: json['qcPassedAt'] as String?,
      currentLocation: json['currentLocation'] as String? ?? 'warehouse',
      currentCenterId: json['currentCenterId'] as String? ?? 'f1',
      protocolId: json['protocolId'] as String?,
      status: json['status'] as String? ?? 'sealed',
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'deviceType': deviceType,
        'modelName': modelName,
        'manufacturer': manufacturer,
        'lotNumber': lotNumber,
        'serialNumber': serialNumber,
        'manufactureDate': manufactureDate.toIso8601String(),
        'expiryDate': expiryDate?.toIso8601String(),
        'qcPassedAt': qcPassedAt,
        'currentLocation': currentLocation,
        'currentCenterId': currentCenterId,
        'protocolId': protocolId,
        'status': status,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  String get displayLabel =>
      '$modelName · $lotNumber/$serialNumber';
  bool get inUse => status == 'in-use';
  bool get isDamaged => status == 'damaged';
  bool get isDisposed => status == 'disposed';
}
