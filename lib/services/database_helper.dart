import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    String path = join(await getDatabasesPath(), 'app_cache.db');
    return await openDatabase(
      path,
      version: 2, // Incremented version
      onCreate: _onCreate,
      onUpgrade: _onUpgrade, // Added for migration
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Create all tables for a fresh install
    await db.execute('''
      CREATE TABLE student_profile (
        id TEXT PRIMARY KEY,
        name TEXT,
        email TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE timetable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        day TEXT,
        course_name TEXT,
        start_time TEXT,
        end_time TEXT,
        professor TEXT,
        location TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE teacher_schedule (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        day TEXT,
        courseName TEXT,
        className TEXT,
        location TEXT,
        startTime TEXT,
        endTime TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE courses (
        course_id TEXT PRIMARY KEY,
        course_name TEXT,
        credit_hours INTEGER,
        teacher_name TEXT,
        student_class TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE fee_details (
        challanNo TEXT PRIMARY KEY,
        term TEXT,
        amount TEXT,
        dueDate TEXT,
        status TEXT,
        depositDate TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE attendance (
        courseId TEXT PRIMARY KEY,
        subject TEXT,
        shortName TEXT,
        presentHours INTEGER,
        absentHours INTEGER,
        totalHours INTEGER,
        attendancePercentage REAL
      )
    ''');

    await db.execute('''
      CREATE TABLE transcript_semesters (
        semester_name TEXT PRIMARY KEY,
        gpa REAL,
        cgpa REAL
      )
    ''');

    await db.execute('''
      CREATE TABLE transcript_courses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        semester_name TEXT,
        course_code TEXT,
        course_title TEXT,
        credit_hours INTEGER,
        grade_points REAL,
        grade TEXT,
        FOREIGN KEY (semester_name) REFERENCES transcript_semesters (semester_name)
      )
    ''');
  }

  // Handles migrations for existing users.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE teacher_schedule (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          day TEXT,
          courseName TEXT,
          className TEXT,
          location TEXT,
          startTime TEXT,
          endTime TEXT
        )
      ''');
    }
  }

  // Generic cache update
  Future<void> cacheData(String tableName, List<Map<String, dynamic>> data,
      {String? conflictAlgorithm}) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(tableName); // Clear old data
      for (var item in data) {
        await txn.insert(
          tableName,
          item,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  // Generic cache retrieval
  Future<List<Map<String, dynamic>>> getCachedData(String tableName) async {
    final db = await database;
    return await db.query(tableName);
  }
}