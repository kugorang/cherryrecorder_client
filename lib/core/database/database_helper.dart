import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  // 데이터베이스 설정
  static const String _databaseName = "cherry_recorder.db";
  static const int _databaseVersion = 1;

  // 테이블 및 컬럼 정의
  static const String tableMemo = 'memo';
  static const String columnId = 'id';
  static const String columnPlaceId = 'place_id';
  static const String columnContent = 'content';
  static const String columnTags = 'tags';
  static const String columnCreatedAt = 'created_at';
  static const String columnUpdatedAt = 'updated_at';

  // 싱글톤 패턴 구현
  DatabaseHelper._init();
  static final DatabaseHelper instance = DatabaseHelper._init();

  // 데이터베이스 인스턴스
  static Database? _database;
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB(_databaseName);
    return _database!;
  }

  // 데이터베이스 초기화
  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
    );
  }

  // 테이블 생성
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableMemo (
        $columnId TEXT PRIMARY KEY,
        $columnPlaceId TEXT NOT NULL,
        $columnContent TEXT NOT NULL,
        $columnTags TEXT,
        $columnCreatedAt TEXT NOT NULL,
        $columnUpdatedAt TEXT NOT NULL
      )
    ''');
  }

  // 메모 삽입
  Future<int> insertMemo(Map<String, dynamic> row) async {
    final db = await database;
    return await db.insert(tableMemo, row);
  }

  // 특정 장소의 메모 조회
  Future<List<Map<String, dynamic>>> queryMemos(String placeId) async {
    final db = await database;
    return await db.query(
      tableMemo,
      where: '$columnPlaceId = ?',
      whereArgs: [placeId],
      orderBy: '$columnCreatedAt DESC',
    );
  }

  // 메모 수정
  Future<int> updateMemo(Map<String, dynamic> row) async {
    final db = await database;
    final id = row[columnId];
    return await db.update(
      tableMemo,
      row,
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  // 메모 삭제
  Future<int> deleteMemo(String id) async {
    final db = await database;
    return await db.delete(tableMemo, where: '$columnId = ?', whereArgs: [id]);
  }

  // 모든 메모 조회
  Future<List<Map<String, dynamic>>> queryAllMemos() async {
    final db = await database;
    return await db.query(tableMemo, orderBy: '$columnCreatedAt DESC');
  }

  // 메모 검색
  Future<List<Map<String, dynamic>>> searchMemos(String query) async {
    final db = await database;
    return await db.query(
      tableMemo,
      where: '$columnContent LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: '$columnCreatedAt DESC',
    );
  }
}
