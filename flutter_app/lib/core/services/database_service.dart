import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/expense_model.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  Database? _db;

  factory DatabaseService() => _instance;

  DatabaseService._internal();

  Future<void> init() async {
    if (_db != null) return;
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'expense_tracker.db');

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE expenses (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            expenseId TEXT UNIQUE NOT NULL,
            amount REAL NOT NULL,
            category TEXT NOT NULL,
            note TEXT,
            date TEXT NOT NULL,
            imageUrl TEXT,
            imageLocalPath TEXT,
            synced INTEGER NOT NULL DEFAULT 0,
            createdAt TEXT NOT NULL,
            updatedAt TEXT NOT NULL,
            receiptText TEXT
          )
        ''');
        await db.execute('CREATE INDEX idx_expenses_date ON expenses(date DESC)');
        await db.execute('CREATE INDEX idx_expenses_synced ON expenses(synced)');
        await db.execute('CREATE INDEX idx_expenses_category ON expenses(category)');
      },
    );
  }

  Future<Database> _database() async {
    if (_db == null) await init();
    return _db!;
  }

  Future<void> saveExpense(ExpenseModel expense) async {
    final db = await _database();
    await db.insert(
      'expenses',
      expense.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<ExpenseModel?> getExpense(String expenseId) async {
    final db = await _database();
    final rows = await db.query(
      'expenses',
      where: 'expenseId = ?',
      whereArgs: [expenseId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ExpenseModel.fromMap(rows.first);
  }

  Future<List<ExpenseModel>> getAllExpenses({bool onlySynced = false}) async {
    final db = await _database();
    final rows = await db.query(
      'expenses',
      where: onlySynced ? 'synced = 1' : null,
      orderBy: 'date DESC',
    );
    return rows.map(ExpenseModel.fromMap).toList();
  }

  Future<List<ExpenseModel>> getExpensesByCategory(String category) async {
    final db = await _database();
    final rows = await db.query(
      'expenses',
      where: 'category = ?',
      whereArgs: [category],
      orderBy: 'date DESC',
    );
    return rows.map(ExpenseModel.fromMap).toList();
  }

  Future<List<ExpenseModel>> getExpensesNotSynced() async {
    final db = await _database();
    final rows = await db.query(
      'expenses',
      where: 'synced = 0',
      orderBy: 'date DESC',
    );
    return rows.map(ExpenseModel.fromMap).toList();
  }

  Future<double> _totalBetween(DateTime from, DateTime to) async {
    final db = await _database();
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) AS total FROM expenses WHERE date >= ? AND date <= ?',
      [from.toIso8601String(), to.toIso8601String()],
    );
    final raw = result.first['total'];
    if (raw is int) return raw.toDouble();
    if (raw is double) return raw;
    return 0;
  }

  Future<double> getTodayTotal() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    return _totalBetween(start, end);
  }

  Future<double> getWeekTotal() async {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final start = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    return _totalBetween(start, end);
  }

  Future<double> getMonthTotal() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    return _totalBetween(start, end);
  }

  Future<void> deleteExpense(String expenseId) async {
    final db = await _database();
    await db.delete('expenses', where: 'expenseId = ?', whereArgs: [expenseId]);
  }

  Future<void> markAsSynced(String expenseId) async {
    final db = await _database();
    await db.update(
      'expenses',
      {
        'synced': 1,
        'updatedAt': DateTime.now().toIso8601String(),
      },
      where: 'expenseId = ?',
      whereArgs: [expenseId],
    );
  }

  Future<void> clearAll() async {
    final db = await _database();
    await db.delete('expenses');
  }
}
