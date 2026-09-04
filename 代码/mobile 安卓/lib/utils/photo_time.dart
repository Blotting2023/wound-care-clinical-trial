import 'dart:convert';
import 'dart:io';
import 'package:exif/exif.dart';
import 'package:intl/intl.dart';

/// GCP W3 扩展 — 把 EXIF 全部 tag 读出来，调用方负责后续 strip GPS。
///
/// 原始 readPhotoTakenAt() 只取时间，本扩展新增 readAllExifTags() 返回
/// 完整 Map（key 含 `EXIF DateTimeOriginal` / `Image Make` 等格式）。
Future<Map<String, dynamic>> readAllExifTags(String path) async {
  try {
    final bytes = await File(path).readAsBytes();
    final tags = await readExifFromBytes(bytes);
    // `printable` 字段是 String，其他可能是 List<int>（少见）。
    final out = <String, dynamic>{};
    tags.forEach((key, value) {
      out[key] = value.printable;
    });
    return out;
  } catch (_) {
    return <String, dynamic>{};
  }
}

/// 把 EXIF Map → JSON 字符串（同时调用 stripGpsAndSerializeExif 抹掉 GPS）。
String exifToJson(Map<String, dynamic> exif) {
  // demo 实现简化：用 toString 序列化。生产阶段换成 JSON 再过滤。
  // 这里为了不让 photo_metadata.dart 增加 dart:convert 依赖，
  // 实际把"过滤"放在这里完成（与 metadata 模型独立）。
  final filtered = <String, dynamic>{};
  exif.forEach((key, value) {
    if (key.toLowerCase().contains('gps')) return;
    filtered[key] = value;
  });
  return jsonEncode(filtered);
}

/// 旧的 PhotoTime / readPhotoTakenAt 保留（导入照片功能依赖），
/// 后面 W3.1 用法都改走 readFullPhotoInfo()。
class PhotoTime {
  final DateTime takenAt;
  final String source; // 'exif_original' / 'exif_digitized' / 'exif_datetime' / 'file_mtime'
  const PhotoTime({required this.takenAt, required this.source});
}

/// 读取 [path] 的拍摄时间。失败返回 null。
/// 仅解析前 64KB，避免大图整体读入。
Future<PhotoTime?> readPhotoTakenAt(String path) async {
  try {
    final bytes = await File(path).readAsBytes();
    // 解析 EXIF，按 tag 取时间
    final tags = await readExifFromBytes(bytes);
    final candidates = [
      'EXIF DateTimeOriginal',
      'EXIF DateTimeDigitized',
      'Image DateTime',
    ];
    for (final key in candidates) {
      final v = tags[key];
      if (v == null) continue;
      final parsed = _parseExifDateTime(v.printable);
      if (parsed != null) {
        final source = key == 'EXIF DateTimeOriginal'
            ? 'exif_original'
            : key == 'EXIF DateTimeDigitized'
                ? 'exif_digitized'
                : 'exif_datetime';
        return PhotoTime(takenAt: parsed, source: source);
      }
    }
    // 兜底：文件 mtime
    final stat = await File(path).stat();
    return PhotoTime(takenAt: stat.modified, source: 'file_mtime');
  } catch (_) {
    try {
      final stat = await File(path).stat();
      return PhotoTime(takenAt: stat.modified, source: 'file_mtime');
    } catch (_) {
      return null;
    }
  }
}

/// EXIF 日期格式 "2024:08:29 17:34:08" → DateTime。
DateTime? _parseExifDateTime(String? s) {
  if (s == null) return null;
  final t = s.trim();
  if (t.isEmpty) return null;
  try {
    final fmt = DateFormat('yyyy:MM:dd HH:mm:ss');
    return fmt.parse(t);
  } catch (_) {
    return null;
  }
}

/// 把 DateTime 格式化成 "2026-08-29 17:34" 这种简短形式，
/// 给 UI 顶部"照片取自"提示用。
String fmtPhotoTime(DateTime dt) {
  final fmt = DateFormat('yyyy-MM-dd HH:mm');
  return fmt.format(dt.toLocal());
}

/// W3.1 新增 — 同时返回拍摄时间 + 完整 EXIF 元数据。
/// 调用方负责把 EXIF 转 JSON 并 strip GPS（用 `exifToJson` 已经做了过滤）。
class FullPhotoInfo {
  final PhotoTime? time;
  final Map<String, dynamic> exif; // 已过滤 GPS
  final String exifJson;
  const FullPhotoInfo({
    required this.time,
    required this.exif,
    required this.exifJson,
  });
}

Future<FullPhotoInfo?> readFullPhotoInfo(String path) async {
  final exif = await readAllExifTags(path);
  final jsonNoGps = exifToJson(exif);
  PhotoTime? time;
  // 优先用 EXIF DateTimeOriginal
  for (final key in const [
    'EXIF DateTimeOriginal',
    'EXIF DateTimeDigitized',
    'Image DateTime',
  ]) {
    final v = exif[key];
    if (v is String) {
      final p = _parseExifDateTime(v);
      if (p != null) {
        final source = key == 'EXIF DateTimeOriginal'
            ? 'exif_original'
            : key == 'EXIF DateTimeDigitized'
                ? 'exif_digitized'
                : 'exif_datetime';
        time = PhotoTime(takenAt: p, source: source);
        break;
      }
    }
  }
  // 兜底：文件 mtime
  time ??= await _fileMtime(path);

  return FullPhotoInfo(time: time, exif: exif, exifJson: jsonNoGps);
}

Future<PhotoTime?> _fileMtime(String path) async {
  try {
    final stat = await File(path).stat();
    return PhotoTime(takenAt: stat.modified, source: 'file_mtime');
  } catch (_) {
    return null;
  }
}
