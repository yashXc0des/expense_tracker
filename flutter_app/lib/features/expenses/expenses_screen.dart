import 'package:flutter/material.dart';
import '../../core/services/expense_service.dart';
import '../../core/models/expense_model.dart';
import 'expense_detail_screen.dart';
import 'package:intl/intl.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  late Future<List<ExpenseModel>> _expensesFuture;
  final _searchCtrl = TextEditingController();
  String? _selectedCategory;
  final _expenseService = ExpenseService();

  final List<String> _categories = [
    'All', 'Food', 'Travel', 'Fuel', 'Entertainment', 'Utilities',
    'Hotel', 'Parking', 'Shopping', 'Health', 'Other'
  ];

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  void _loadExpenses() {
    _expensesFuture = _expenseService.getAllExpenses();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Search and filter section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Search box
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (_) => setState(() => _loadExpenses()),
                        decoration: InputDecoration(
                          hintText: 'Search by note...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _showFilterOptions,
                      icon: const Icon(Icons.filter_list),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.teal.shade100,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Category filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _categories.map((cat) {
                      final isSelected = _selectedCategory == null
                          ? cat == 'All'
                          : _selectedCategory == (cat == 'All' ? null : cat);

                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(cat),
                          selected: isSelected,
                          onSelected: (_) {
                            setState(() {
                              _selectedCategory = cat == 'All' ? null : cat;
                              _loadExpenses();
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // Expenses list
          Expanded(
            child: FutureBuilder<List<ExpenseModel>>(
              future: _expensesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 8),
                        Text('Error: ${snapshot.error}'),
                      ],
                    ),
                  );
                }

                var expenses = snapshot.data ?? [];

                // Apply category filter
                if (_selectedCategory != null) {
                  expenses = expenses
                      .where((e) => e.category == _selectedCategory)
                      .toList();
                }

                // Apply search filter
                if (_searchCtrl.text.isNotEmpty) {
                  expenses = expenses
                      .where((e) =>
                          (e.note?.toLowerCase() ?? '')
                              .contains(_searchCtrl.text.toLowerCase()) ||
                          e.category.toLowerCase()
                              .contains(_searchCtrl.text.toLowerCase()))
                      .toList();
                }

                if (expenses.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long, size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 8),
                        const Text('No expenses found'),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    setState(() => _loadExpenses());
                    await Future.delayed(const Duration(milliseconds: 500));
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: expenses.length,
                    itemBuilder: (context, index) {
                      final exp = expenses[index];
                      return _buildExpenseCard(exp);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.pushNamed(context, '/capture');
          if (result == true && mounted) {
            setState(() => _loadExpenses());
          }
        },
        tooltip: 'Add Expense',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildExpenseCard(ExpenseModel expense) {
    final icons = {
      'Food': Icons.shopping_bag,
      'Travel': Icons.flight,
      'Fuel': Icons.local_gas_station,
      'Entertainment': Icons.movie,
      'Utilities': Icons.home,
      'Hotel': Icons.hotel,
      'Parking': Icons.local_parking,
      'Shopping': Icons.shopping_cart,
      'Health': Icons.health_and_safety,
      'Other': Icons.receipt,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () async {
          final deleted = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => ExpenseDetailScreen(expense: expense),
            ),
          );
          if (deleted == true && mounted) {
            setState(() => _loadExpenses());
          }
        },
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border(
                left: BorderSide(
                  color: Colors.teal,
                  width: 4,
                ),
              ),
            ),
            child: Row(
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icons[expense.category] ?? Icons.receipt,
                    color: Colors.teal,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        expense.note ?? expense.category,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        children: [
                          Text(
                            expense.category,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          const Spacer(),
                          if (!expense.synced)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Pending',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Amount and date
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${expense.amount.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.green,
                      ),
                    ),
                    Text(
                      DateFormat('dd/MM/yyyy').format(expense.date),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      builder: (_) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filter & Sort',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('Refresh'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _loadExpenses());
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_sweep),
              title: const Text('Clear Filters'),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _searchCtrl.clear();
                  _selectedCategory = null;
                  _loadExpenses();
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.sync),
              title: const Text('Sync Unsynced Expenses'),
              onTap: () async {
                Navigator.pop(context);
                _syncExpenses();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _syncExpenses() async {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Syncing...'),
        content: const SizedBox(
          height: 50,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
    );

    try {
      final count = await _expenseService.syncUnsyncedExpenses();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Synced $count expenses'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() => _loadExpenses());
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }
}
