/// Generates the GCP-compliant subject identification code used in place of
/// the patient's real name on every screen, report and CRF.
///
/// Format: `<PinyinInitials><4-digit-sequence>`
/// - `<PinyinInitials>` — first letter of each Hanzi in the real name
///   (e.g. `张伟` → `ZW`). Falls back to the first letter of the ASCII name
///   when the name is not Chinese, and to `X` when the name is empty.
/// - `<4-digit-sequence>` — center-scoped sequence number, 1-based with
///   zero-padding. Incremented atomically per (center, prefix).
///
/// **Compliance notes**
/// - The subject code is the only patient identifier that flows to the
///   mobile client in production deployments (GCP §57, PIPL Art. 24).
/// - The mapping `subjectCode → realName + ID + phone` is stored server-side
///   in `PatientIdentityMap` and only exposed via the dedicated identity
///   API for users with role `PI` / `Admin`.
library;

class SubjectCodeGenerator {
  const SubjectCodeGenerator();

  /// Generate the subject code for a patient given their real name and the
  /// next sequence number for the centre. Sequence is 1-based.
  ///
  /// Examples
  ///   generate('张伟', 1)   → 'ZW0001'
  ///   generate('李秀英', 2) → 'LXY0002'
  ///   generate('Alice', 3)  → 'A0003'
  String generate(String realName, int sequence) {
    final prefix = _initials(realName);
    final seq = sequence.clamp(1, 9999).toString().padLeft(4, '0');
    return '$prefix$seq';
  }

  /// Extract the uppercase initial prefix from a name.
  String _initials(String realName) {
    final trimmed = realName.trim();
    if (trimmed.isEmpty) return 'X';

    // ASCII path: take just the first letter to keep codes compact.
    final isAscii = trimmed.codeUnits.every((c) => c < 0x80);
    if (isAscii) {
      return trimmed.substring(0, 1).toUpperCase();
    }

    // Chinese path: take the first letter of each Han character using a
    // built-in dictionary of common-name Hanzi. We then derive the rest
    // heuristically so the *same* character always produces the *same*
    // initial even if it isn't in the table.
    final buf = StringBuffer();
    for (final rune in trimmed.runes) {
      final ch = String.fromCharCode(rune);
      if (ch.trim().isEmpty) continue;
      final letter = _kKnownInitials[ch] ?? _heuristicInitial(rune);
      if (letter != null) buf.write(letter);
    }
    final out = buf.toString();
    return out.isEmpty ? 'X' : out;
  }

  /// Last-resort heuristic for characters we don't have in our known
  /// initials table. Hashes the rune into A-Z so the same character always
  /// produces the same initial.
  String? _heuristicInitial(int rune) {
    if (rune <= 0x4DFF) return null; // outside BMP / non-letter
    final h = rune % 26;
    return String.fromCharCode(0x41 + h);
  }

  /// Hard-coded initials for seeded demo patients + the most common Han
  /// characters found in Chinese names. This table can be expanded without
  /// changing the generator API.
  static const Map<String, String> _kKnownInitials = {
    '张': 'Z', '李': 'L', '王': 'W', '刘': 'L', '陈': 'C', '杨': 'Y',
    '赵': 'Z', '黄': 'H', '周': 'Z', '吴': 'W', '徐': 'X', '孙': 'S',
    '马': 'M', '朱': 'Z', '胡': 'H', '郭': 'G', '何': 'H', '高': 'G',
    '林': 'L', '罗': 'L', '郑': 'Z', '梁': 'L', '谢': 'X', '宋': 'S',
    '唐': 'T', '许': 'X', '邓': 'D', '韩': 'H', '冯': 'F', '曹': 'C',
    '彭': 'P', '曾': 'Z', '萧': 'X', '田': 'T', '董': 'D', '袁': 'Y',
    '潘': 'P', '于': 'Y', '蒋': 'J', '蔡': 'C', '余': 'Y', '杜': 'D',
    '叶': 'Y', '程': 'C', '苏': 'S', '魏': 'W', '吕': 'L', '丁': 'D',
    '任': 'R', '沈': 'S', '姚': 'Y', '卢': 'L', '姜': 'J', '崔': 'C',
    '钟': 'Z', '谭': 'T', '陆': 'L', '汪': 'W', '范': 'F',
    '石': 'S', '廖': 'L', '贾': 'J', '夏': 'X', '韦': 'W', '付': 'F',
    '方': 'F', '白': 'B', '邹': 'Z', '孟': 'M', '熊': 'X', '秦': 'Q',
    '邱': 'Q', '江': 'J', '尹': 'Y', '薛': 'X', '闫': 'Y', '段': 'D',
    '雷': 'L', '侯': 'H', '龙': 'L', '史': 'S', '陶': 'T', '黎': 'L',
    '贺': 'H', '顾': 'G', '毛': 'M', '郝': 'H', '龚': 'G', '邵': 'S',
    '万': 'W', '钱': 'Q', '严': 'Y', '赖': 'L', '覃': 'T', '伍': 'W',
    '洪': 'H', '文': 'W', '秀': 'X', '英': 'Y', '建': 'J', '国': 'G',
    '伟': 'W', '敏': 'M', '丽': 'L', '强': 'Q', '磊': 'L', '军': 'J',
    '洋': 'Y', '勇': 'Y', '艳': 'Y', '杰': 'J', '娟': 'J', '明': 'M',
    '超': 'C', '霞': 'X', '平': 'P', '刚': 'G', '桂': 'G',
  };
}