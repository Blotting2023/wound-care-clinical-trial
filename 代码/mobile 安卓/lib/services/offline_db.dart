import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../models/assessment.dart';

/// Local SQLite database for draft assessments when offline.
class OfflineDb {
  static Database? _database;

  /// Open (or create) the database at the app's documents directory.
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'wound_assessment_offline.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS draft_assessments (
        id TEXT PRIMARY KEY,
        patient_id TEXT NOT NULL,
        wound_id TEXT NOT NULL,
        local_image_paths TEXT,
        status TEXT NOT NULL DEFAULT 'draft',
        created_at TEXT NOT NULL,
        json_data TEXT NOT NULL
      )
    ''');
  }

  /// Insert or replace a draft assessment.
  Future<void> insertDraft(Assessment assessment,
      {List<String>? imagePaths}) async {
    final db = await database;
    await db.insert(
      'draft_assessments',
      {
        'id': assessment.id,
        'patient_id': assessment.patientId,
        'wound_id': assessment.woundId,
        'local_image_paths': imagePaths != null
            ? jsonEncode(imagePaths)
            : null,
        'status': assessment.status.value,
        'created_at': assessment.createdAt.toIso8601String(),
        'json_data': jsonEncode(assessment.toJson()),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Retrieve all draft assessments.
  Future<List<Assessment>> getAllDrafts() async {
    final db = await database;
    final rows = await db.query('draft_assessments',
        orderBy: 'created_at DESC');

    return rows.map((row) {
      final json = jsonDecode(row['json_data'] as String)
          as Map<String, dynamic>;
      return Assessment.fromJson(json);
    }).toList();
  }

  /// Get a specific draft by ID.
  Future<Assessment?> getDraft(String id) async {
    final db = await database;
    final rows = await db.query(
      'draft_assessments',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final json =
        jsonDecode(rows.first['json_data'] as String) as Map<String, dynamic>;
    return Assessment.fromJson(json);
  }

  /// Delete a draft by ID.
  Future<void> deleteDraft(String id) async {
    final db = await database;
    await db.delete(
      'draft_assessments',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Get the image paths stored for a draft.
  Future<List<String>?> getDraftImagePaths(String id) async {
    final db = await database;
    final rows = await db.query(
      'draft_assessments',
      columns: ['local_image_paths'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty || rows.first['local_image_paths'] == null) return null;
    return List<String>.from(
      jsonDecode(rows.first['local_image_paths'] as String) as List,
    );
  }

  /// Count all draft assessments (for badge display).
  Future<int> countDrafts() async {
    final db = await database;
    final result =
        await db.rawQuery('SELECT COUNT(*) as count FROM draft_assessments');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Clear all drafts (on logout).
  Future<void> clearAll() async {
    final db = await database;
    await db.delete('draft_assessments');
  }

  /// Close the database connection.
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
