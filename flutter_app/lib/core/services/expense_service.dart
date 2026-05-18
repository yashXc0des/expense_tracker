import 'dart:io';
import 'package:dio/dio.dart';
import '../models/expense_model.dart';
import 'database_service.dart';
import 'api_service.dart';

class ExpenseService {
  static final ExpenseService _instance = ExpenseService._internal();
  final _db = DatabaseService();
  final _api = ApiService.instance;
  late Dio _dio;

  factory ExpenseService() {
    return _instance;
  }

  ExpenseService._internal() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
    ));
  }

  /// Create expense locally and upload to backend with image
  Future<bool> createExpense({
    required ExpenseModel expense,
    File? imageFile,
  }) async {
    try {
      print('[ExpenseService] Creating expense: ${expense.expenseId}');

      // Save locally first (for offline support)
      expense.imageLocalPath = imageFile?.path;
      await _db.saveExpense(expense);

      // Try to upload to backend
      final success = await _uploadExpense(expense, imageFile);
      if (success) {
        await _db.markAsSynced(expense.expenseId);
      }
      return true;
    } catch (e) {
      print('[ExpenseService] Error creating expense: $e');
      // Expense is still saved locally, will sync later
      return true;
    }
  }

  /// Upload expense to backend with image
  Future<bool> _uploadExpense(ExpenseModel expense, File? imageFile) async {
    try {
      print('[ExpenseService] Uploading expense to backend');
      final token = await _api.getToken();

      if (token == null || token.isEmpty) {
        print('[ExpenseService] No auth token available, postponing sync');
        return false;
      }

      final formData = FormData.fromMap({
        'amount': expense.amount,
        'category': expense.category,
        'note': expense.note ?? '',
        'date': expense.date.toIso8601String(),
        'receiptText': expense.receiptText ?? '',
      });

      // Add image if available
      if (imageFile != null && imageFile.existsSync()) {
        formData.files.add(MapEntry(
          'receipt',
          await MultipartFile.fromFile(
            imageFile.path,
            filename: imageFile.path.split('/').last,
          ),
        ));
      }

      final response = await _dio.post(
        '${ApiService.instance.baseUrl}/expenses',
        data: formData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('[ExpenseService] Upload successful');
        return true;
      }
      return false;
    } catch (e) {
      print('[ExpenseService] Upload error: $e');
      return false;
    }
  }

  /// Sync all unsynced expenses
  Future<int> syncUnsyncedExpenses() async {
    try {
      final unsyncedExpenses = await _db.getExpensesNotSynced();
      print('[ExpenseService] Found ${unsyncedExpenses.length} unsynced expenses');

      int successCount = 0;
      for (final expense in unsyncedExpenses) {
        final imageFile = expense.imageLocalPath != null
            ? File(expense.imageLocalPath!)
            : null;
        
        final success = await _uploadExpense(expense, imageFile);
        if (success) {
          await _db.markAsSynced(expense.expenseId);
          successCount++;
        }
      }
      return successCount;
    } catch (e) {
      print('[ExpenseService] Sync error: $e');
      return 0;
    }
  }

  /// Get all expenses (local first, then sync)
  Future<List<ExpenseModel>> getAllExpenses() async {
    return await _db.getAllExpenses();
  }

  /// Get expenses by category
  Future<List<ExpenseModel>> getExpensesByCategory(String category) async {
    return await _db.getExpensesByCategory(category);
  }

  /// Delete expense
  Future<bool> deleteExpense(String expenseId) async {
    try {
      print('[ExpenseService] Deleting expense: $expenseId');

      // Try to delete from backend
      try {
        await _api.delete('/expenses/$expenseId');
      } catch (_) {
        // Backend delete failed, but continue with local delete
        print('[ExpenseService] Backend delete failed, continuing with local delete');
      }

      // Delete locally
      await _db.deleteExpense(expenseId);
      return true;
    } catch (e) {
      print('[ExpenseService] Error deleting expense: $e');
      return false;
    }
  }

  /// Get summary
  Future<Map<String, dynamic>> getSummary() async {
    try {
      final today = await _db.getTodayTotal();
      final week = await _db.getWeekTotal();
      final month = await _db.getMonthTotal();
      final count = (await _db.getAllExpenses()).length;

      return {
        'today': {'total': today, 'count': (await _db.getAllExpenses()).where((e) {
          final now = DateTime.now();
          final startOfDay = DateTime(now.year, now.month, now.day);
          return e.date.isAfter(startOfDay);
        }).length},
        'week': {'total': week},
        'month': {'total': month, 'count': count},
      };
    } catch (e) {
      print('[ExpenseService] Error getting summary: $e');
      return {
        'today': {'total': 0, 'count': 0},
        'week': {'total': 0},
        'month': {'total': 0, 'count': 0},
      };
    }
  }

  /// Delete all expenses (for testing)
  Future<void> clearAll() async {
    await _db.clearAll();
  }
}
