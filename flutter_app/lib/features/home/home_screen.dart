import 'package:flutter/material.dart';
import '../camera/camera_screen.dart';
import '../expenses/expenses_screen.dart';
import '../journeys/journeys_screen.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/expense_service.dart';
import '../../core/models/expense_model.dart';

class HomeScreen extends StatefulWidget {
  final Function(ThemeMode) onThemeChanged;
  final ThemeMode themeMode;
  const HomeScreen({super.key, required this.onThemeChanged, required this.themeMode});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const DashboardTab(),
    const CameraScreen(),
    const ExpensesScreen(),
    const JourneysScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Tracker'),
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'light') widget.onThemeChanged(ThemeMode.light);
              if (v == 'dark') widget.onThemeChanged(ThemeMode.dark);
              if (v == 'system') widget.onThemeChanged(ThemeMode.system);
              if (v == 'logout') _logout();
            },
            itemBuilder: (_) => [
              CheckedPopupMenuItem(
                value: 'light',
                checked: widget.themeMode == ThemeMode.light,
                child: const Text('Light Theme'),
              ),
              CheckedPopupMenuItem(
                value: 'dark',
                checked: widget.themeMode == ThemeMode.dark,
                child: const Text('Dark Theme'),
              ),
              CheckedPopupMenuItem(
                value: 'system',
                checked: widget.themeMode == ThemeMode.system,
                child: const Text('System Theme'),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'logout', child: Text('Logout')),
            ],
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.camera_alt), label: 'Capture'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'Expenses'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Journeys'),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Logout')),
        ],
      ),
    );
    if (confirm == true) {
      await AuthService.instance.clear();
      if (mounted) Navigator.pushReplacementNamed(context, '/');
    }
  }
}

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  late Future<Map<String, dynamic>> _summaryFuture;
  final _expenseService = ExpenseService();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _summaryFuture = _expenseService.getSummary();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => setState(() => _loadData()),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary cards
            FutureBuilder<Map<String, dynamic>>(
              future: _summaryFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const ShimmerRow();
                }
                if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                }
                final today = snapshot.data?['today'] ?? {'total': 0, 'count': 0};
                final month = snapshot.data?['month'] ?? {'total': 0, 'count': 0};
                return Row(
                  children: [
                    Expanded(
                      child: SummaryCard(
                        title: 'Today',
                        amount: '₹${(today['total'] ?? 0).toStringAsFixed(0)}',
                        icon: Icons.today,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SummaryCard(
                        title: 'This Month',
                        amount: '₹${(month['total'] ?? 0).toStringAsFixed(0)}',
                        icon: Icons.calendar_month,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<ExpenseModel>>(
              future: _expenseService.getAllExpenses(),
              builder: (context, snapshot) {
                final expenses = snapshot.data ?? [];
                return Row(
                  children: [
                    Expanded(
                      child: SummaryCard(
                        title: 'Journeys',
                        amount: '0',
                        icon: Icons.map,
                        color: Colors.teal,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SummaryCard(
                        title: 'Total',
                        amount: expenses.length.toString(),
                        icon: Icons.receipt,
                        color: Colors.purple,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            // Recent transactions
            Text(
              'Recent Transactions',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<ExpenseModel>>(
              future: _expenseService.getAllExpenses(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return Text('Error loading expenses: ${snapshot.error}');
                }
                final expenses = snapshot.data?.take(5).toList() ?? [];
                if (expenses.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('No expenses yet')),
                  );
                }
                final icons = {
                  'Food': Icons.shopping_bag,
                  'Travel': Icons.flight,
                  'Fuel': Icons.local_gas_station,
                  'Entertainment': Icons.movie,
                  'Utilities': Icons.home,
                  'Hotel': Icons.hotel,
                  'Parking': Icons.local_parking,
                  'Shopping': Icons.shopping_cart,
                };
                return Column(
                  children: expenses.map((exp) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TransactionTile(
                        title: exp.note ?? exp.category,
                        amount: '₹${exp.amount.toStringAsFixed(0)}',
                        icon: icons[exp.category] ?? Icons.receipt,
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class ShimmerRow extends StatelessWidget {
  const ShimmerRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }
}

class SummaryCard extends StatelessWidget {
  final String title;
  final String amount;
  final IconData icon;
  final Color color;

  const SummaryCard({
    super.key,
    required this.title,
    required this.amount,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(amount, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class TransactionTile extends StatelessWidget {
  final String title;
  final String amount;
  final IconData icon;

  const TransactionTile({
    super.key,
    required this.title,
    required this.amount,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.teal.shade50,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.teal, size: 24),
        ),
        title: Text(title),
        trailing: Text(
          amount,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }
}
