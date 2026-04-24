import 'dart:async';
import 'dart:convert';
import 'dart:io';

class JsonlReader {
  JsonlReader._();

  static Future<List<Map<String, dynamic>>> readObjects(File file) async {
    if (!await file.exists()) return const [];

    final rows = <Map<String, dynamic>>[];
    try {
      final stream = file
          .openRead()
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final line in stream) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        try {
          final decoded = json.decode(trimmed);
          if (decoded is Map<String, dynamic>) rows.add(decoded);
        } catch (_) {
          // Skip malformed lines — JSONL producers sometimes flush partial writes.
        }
      }
    } on FileSystemException {
      return const [];
    }
    return rows;
  }

  /// Collects every `*.jsonl` file under [root], recursing into subdirectories.
  static Future<List<File>> collectJsonlFiles(Directory root) async {
    if (!await root.exists()) return const [];
    final out = <File>[];
    try {
      await for (final entity
          in root.list(recursive: true, followLinks: false)) {
        if (entity is File && entity.path.endsWith('.jsonl')) {
          out.add(entity);
        }
      }
    } on FileSystemException {
      return const [];
    }
    return out;
  }
}

int asInt(Object? value) {
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  if (value is List) return value.length;
  return 0;
}

String? asNonEmptyString(Object? value) {
  if (value is String && value.isNotEmpty) return value;
  return null;
}

double asDouble(Object? value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}
