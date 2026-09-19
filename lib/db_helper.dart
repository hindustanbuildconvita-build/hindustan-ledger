import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('construction_offline.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE projects (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE transactions_ledger (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        project_id INTEGER,
        type TEXT NOT NULL,
        category TEXT,
        amount REAL NOT NULL,
        details TEXT,
        date TEXT NOT NULL
      )
    ''');
    await db.insert('projects', {'name': 'Site Alpha (Main Project)'});
  }

  Future<int> insertTransaction(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('transactions_ledger', row);
  }

  Future<List<Map<String, dynamic>>> getTransactions(int projectId) async {
    final db = await instance.database;
    return await db.query(
      'transactions_ledger',
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'id DESC',
    );
  }

  Future<Map<String, double>> getFinancialSummary(int projectId) async {
    final db = await instance.database;
    final res = await db.rawQuery('''
      SELECT 
        SUM(CASE WHEN type = 'INCOME' THEN amount ELSE 0 END) as total_income,
        SUM(CASE WHEN type = 'EXPENSE' THEN amount ELSE 0 END) as total_expense,
        SUM(CASE WHEN type = 'LABOR' THEN amount ELSE 0 END) as total_labor
      FROM transactions_ledger
      WHERE project_id = ?
    ''', [projectId]);

    double income = (res.first['total_income'] as num?)?.toDouble() ?? 0.0;
    double expense = (res.first['total_expense'] as num?)?.toDouble() ?? 0.0;
    double labor = (res.first['total_labor'] as num?)?.toDouble() ?? 0.0;

    return {
      'income': income,
      'expense': expense,
      'labor': labor,
      'profit': income - (expense + labor),
    };
  }
}
