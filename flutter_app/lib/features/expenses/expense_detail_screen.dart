import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import '../../core/models/expense_model.dart';
import '../../core/services/expense_service.dart';
import 'package:intl/intl.dart';
import 'dart:io';

class ExpenseDetailScreen extends StatefulWidget {
  final ExpenseModel expense;

  const ExpenseDetailScreen({super.key, required this.expense});

  @override
  State<ExpenseDetailScreen> createState() => _ExpenseDetailScreenState();
}

class _ExpenseDetailScreenState extends State<ExpenseDetailScreen> {
  late ExpenseModel _expense;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _expense = widget.expense;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Details'),
        actions: [
          if (!_isDeleting)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: _showDeleteDialog,
            ),
        ],
      ),
      body: _isDeleting
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image section
                  if (_expense.imageUrl != null || _expense.imageLocalPath != null)
                    Container(
                      width: double.infinity,
                      height: 300,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.teal),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.grey.shade200,
                      ),
                      child: _buildImageViewer(),
                    ),
                  const SizedBox(height: 24),

                  // Amount card
                  _buildDetailCard(
                    icon: Icons.currency_rupee,
                    label: 'Amount',
                    value: '₹${_expense.amount.toStringAsFixed(2)}',
                    color: Colors.green,
                  ),
                  const SizedBox(height: 12),

                  // Category card
                  _buildDetailCard(
                    icon: Icons.category,
                    label: 'Category',
                    value: _expense.category,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 12),

                  // Date card
                  _buildDetailCard(
                    icon: Icons.calendar_today,
                    label: 'Date',
                    value: DateFormat('dd MMM yyyy').format(_expense.date),
                    color: Colors.purple,
                  ),
                  const SizedBox(height: 12),

                  // Status card
                  _buildDetailCard(
                    icon: _expense.synced ? Icons.cloud_done : Icons.cloud_off,
                    label: 'Status',
                    value: _expense.synced ? 'Synced' : 'Pending Sync',
                    color: _expense.synced ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(height: 24),

                  // Note section
                  if (_expense.note != null && _expense.note!.isNotEmpty) ...[
                    Text(
                      'Note',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        border: Border.all(color: Colors.teal.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(_expense.note ?? ''),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // OCR text section
                  if (_expense.receiptText != null && _expense.receiptText!.isNotEmpty) ...[
                    Text(
                      'Extracted Text',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        border: Border.all(color: Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _expense.receiptText ?? '',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Metadata
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Created: ${DateFormat('dd MMM yyyy HH:mm').format(_expense.createdAt)}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ID: ${_expense.expenseId.substring(0, 8)}...',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildDetailCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              Text(
                value,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImageViewer() {
    if (_expense.imageUrl != null) {
      // Display remote image with zoom
      return PhotoView(
        imageProvider: NetworkImage(_expense.imageUrl!),
        minScale: PhotoViewComputedScale.contained * 1.0,
        maxScale: PhotoViewComputedScale.covered * 2.0,
        loadingBuilder: (context, event) => Center(
          child: CircularProgressIndicator(
            value: event == null
                ? 0
                : event.cumulativeBytesLoaded / (event.expectedTotalBytes ?? 1),
          ),
        ),
        errorBuilder: (context, error, stackTrace) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 40, color: Colors.red),
              const SizedBox(height: 8),
              const Text('Failed to load image'),
            ],
          ),
        ),
      );
    } else if (_expense.imageLocalPath != null) {
      final file = File(_expense.imageLocalPath!);
      if (file.existsSync()) {
        return PhotoView(
          imageProvider: FileImage(file),
          minScale: PhotoViewComputedScale.contained * 1.0,
          maxScale: PhotoViewComputedScale.covered * 2.0,
        );
      }
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.image_not_supported, size: 40, color: Colors.grey),
          const SizedBox(height: 8),
          const Text('No image available'),
        ],
      ),
    );
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expense?'),
        content: const Text(
          'Are you sure you want to delete this expense? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteExpense();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteExpense() async {
    setState(() => _isDeleting = true);

    try {
      final expenseService = ExpenseService();
      final success = await expenseService.deleteExpense(_expense.expenseId);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Expense deleted'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true); // Return true to indicate deletion
        } else {
          setState(() => _isDeleting = false);
          _showError('Failed to delete expense');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDeleting = false);
        _showError('Error: $e');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}
