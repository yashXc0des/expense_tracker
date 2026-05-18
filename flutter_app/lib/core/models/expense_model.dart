import 'package:uuid/uuid.dart';

class ExpenseModel {
  int? id; // SQLite primary key
  
  late String expenseId; // Sync ID with backend
  String? journeyId;
  late double amount;
  late String category;
  String? note;
  late DateTime date;
  String? imageUrl; // URL from backend/R2
  String? imageLocalPath; // Local temporary path
  late bool synced; // Whether it's synced to backend
  late DateTime createdAt;
  late DateTime updatedAt;
  String? receiptText; // Raw OCR text

  // Constructor
  ExpenseModel({
    required this.amount,
    required this.category,
    this.journeyId,
    this.note,
    required this.date,
    this.imageUrl,
    this.imageLocalPath,
    bool synced = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.receiptText,
    String? expenseId,
  })  : expenseId = expenseId ?? const Uuid().v4(),
        synced = synced,
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // Convert to JSON for API
  Map<String, dynamic> toJson() {
    return {
      'expenseId': expenseId,
      'journeyId': journeyId,
      'amount': amount,
      'category': category,
      'note': note,
      'date': date.toIso8601String(),
      'imageUrl': imageUrl,
      'receiptText': receiptText,
    };
  }

  // Create from JSON (from API response)
  factory ExpenseModel.fromJson(Map<String, dynamic> json) {
    return ExpenseModel(
      expenseId: json['_id'] ?? json['expenseId'],
      journeyId: json['journeyId']?.toString(),
      amount: (json['amount'] as num).toDouble(),
      category: json['category'] as String,
      note: json['note'] as String?,
      date: json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
      imageUrl: json['imageUrl'] as String?,
      synced: true,
      receiptText: json['receiptText'] as String?,
    );
  }

  @override
  String toString() => 'Expense(id: $expenseId, amount: ₹$amount, category: $category)';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'expenseId': expenseId,
      'journeyId': journeyId,
      'amount': amount,
      'category': category,
      'note': note,
      'date': date.toIso8601String(),
      'imageUrl': imageUrl,
      'imageLocalPath': imageLocalPath,
      'synced': synced ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'receiptText': receiptText,
    };
  }

  factory ExpenseModel.fromMap(Map<String, dynamic> map) {
    return ExpenseModel(
      expenseId: map['expenseId'] as String?,
      journeyId: map['journeyId'] as String?,
      amount: (map['amount'] as num).toDouble(),
      category: map['category'] as String,
      note: map['note'] as String?,
      date: DateTime.parse(map['date'] as String),
      imageUrl: map['imageUrl'] as String?,
      imageLocalPath: map['imageLocalPath'] as String?,
      synced: (map['synced'] as int? ?? 0) == 1,
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt'] as String) : DateTime.now(),
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt'] as String) : DateTime.now(),
      receiptText: map['receiptText'] as String?,
    )..id = map['id'] as int?;
  }
}
