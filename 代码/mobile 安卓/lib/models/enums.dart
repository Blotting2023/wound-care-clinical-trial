/// Status enums used throughout the wound assessment system.
enum AssessmentStatus {
  draft,
  pendingSignature,
  locked,
  archived;

  String get value => name;

  static AssessmentStatus fromString(String s) {
    return AssessmentStatus.values.firstWhere(
      (e) => e.value == s,
      orElse: () => AssessmentStatus.draft,
    );
  }
}

/// Image type classification.
enum ImageType {
  calibration,
  woundCapture,
  reference;

  String get value => name;

  static ImageType fromString(String s) {
    return ImageType.values.firstWhere(
      (e) => e.value == s,
      orElse: () => ImageType.woundCapture,
    );
  }
}

/// Wound tissue types used in AI segmentation and manual overrides.
enum TissueType {
  granulation,
  slough,
  eschar,
  epithelialization,
  undermining;

  String get value => name;

  static TissueType fromString(String s) {
    return TissueType.values.firstWhere(
      (e) => e.value == s,
      orElse: () => TissueType.granulation,
    );
  }
}

/// Exudate levels.
enum ExudateLevel {
  none,
  light,
  moderate,
  heavy;

  String get value => name;

  static ExudateLevel fromString(String s) {
    return ExudateLevel.values.firstWhere(
      (e) => e.value == s,
      orElse: () => ExudateLevel.none,
    );
  }
}

/// Wound edge descriptors.
enum WoundEdge {
  defined,
  diffuse,
  rolled,
  undermined;

  String get value => name;

  static WoundEdge fromString(String s) {
    return WoundEdge.values.firstWhere(
      (e) => e.value == s,
      orElse: () => WoundEdge.defined,
    );
  }
}

/// Peri-wound skin condition.
enum PeriWoundSkin {
  intact,
  macerated,
  erythematous,
  excoriated,
  dry;

  String get value => name;

  static PeriWoundSkin fromString(String s) {
    return PeriWoundSkin.values.firstWhere(
      (e) => e.value == s,
      orElse: () => PeriWoundSkin.intact,
    );
  }
}

/// Sign-off method for locked assessments.
enum SignOffMethod {
  pin,
  biometric;

  String get value => name;

  static SignOffMethod fromString(String s) {
    return SignOffMethod.values.firstWhere(
      (e) => e.value == s,
      orElse: () => SignOffMethod.pin,
    );
  }
}
