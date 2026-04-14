import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/task.dart';
import '../models/operation.dart';

class StorageService {
  static Database? _database;
  static const String _tasksTable = 'tasks';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'clonex.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tasksTable (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            description TEXT,
            operations TEXT NOT NULL,
            intentSummary TEXT,
            createdAt TEXT NOT NULL,
            lastPlayedAt TEXT,
            playCount INTEGER DEFAULT 0
          )
        ''');
      },
    );
  }

  Future<void> saveTask(Task task) async {
    final db = await database;
    final data = {
      'id': task.id,
      'name': task.name,
      'description': task.description,
      'operations': jsonEncode(task.operations.map((o) => o.toJson()).toList()),
      'intentSummary': task.intentSummary,
      'createdAt': task.createdAt.toIso8601String(),
      'lastPlayedAt': task.lastPlayedAt?.toIso8601String(),
      'playCount': task.playCount,
    };

    await db.insert(
      _tasksTable,
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Task>> getAllTasks() async {
    final db = await database;
    final maps = await db.query(_tasksTable, orderBy: 'createdAt DESC');

    return maps.map((map) {
      final operationsJson = jsonDecode(map['operations'] as String) as List;
      return Task(
        id: map['id'] as String,
        name: map['name'] as String,
        description: map['description'] as String?,
        operations: operationsJson
            .map((o) => Operation.fromJson(o as Map<String, dynamic>))
            .toList(),
        intentSummary: map['intentSummary'] as String?,
        createdAt: DateTime.parse(map['createdAt'] as String),
        lastPlayedAt: map['lastPlayedAt'] != null
            ? DateTime.parse(map['lastPlayedAt'] as String)
            : null,
        playCount: map['playCount'] as int? ?? 0,
      );
    }).toList();
  }

  Future<Task?> getTaskById(String id) async {
    final db = await database;
    final maps = await db.query(
      _tasksTable,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isEmpty) return null;

    final map = maps.first;
    final operationsJson = jsonDecode(map['operations'] as String) as List;
    return Task(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      operations: operationsJson
          .map((o) => Operation.fromJson(o as Map<String, dynamic>))
          .toList(),
      intentSummary: map['intentSummary'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      lastPlayedAt: map['lastPlayedAt'] != null
          ? DateTime.parse(map['lastPlayedAt'] as String)
          : null,
      playCount: map['playCount'] as int? ?? 0,
    );
  }

  Future<void> deleteTask(String id) async {
    final db = await database;
    await db.delete(_tasksTable, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateTask(Task task) async {
    await saveTask(task);
  }
}
