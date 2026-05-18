import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';

class JourneyDetailScreen extends StatefulWidget {
  final String journeyId;
  final String title;

  const JourneyDetailScreen({
    super.key,
    required this.journeyId,
    required this.title,
  });

  @override
  State<JourneyDetailScreen> createState() => _JourneyDetailScreenState();
}

class _JourneyDetailScreenState extends State<JourneyDetailScreen> {
  late Future<Map<String, dynamic>?> _journeyDetailFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _journeyDetailFuture = ApiService.instance.get('/journeys/${widget.journeyId}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _journeyDetailFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Failed to load journey: ${snapshot.error}'),
              ),
            );
          }

          final data = snapshot.data;
          if (data == null || data.isEmpty) {
            return const Center(child: Text('Journey details not found'));
          }

          final expenses = (data['expenses'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          final totalAmount = (data['totalAmount'] ?? 0) as num;
          final expenseCount = (data['expenseCount'] ?? expenses.length) as num;

          return RefreshIndicator(
            onRefresh: () async {
              setState(_load);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (data['name'] ?? widget.title).toString(),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        if ((data['description'] ?? '').toString().isNotEmpty)
                          Text((data['description'] ?? '').toString()),
                        const SizedBox(height: 12),
                        Text('Dates: ${_fmt(data['startDate'])} - ${_fmt(data['endDate'])}'),
                        const SizedBox(height: 6),
                        Text('Total: INR ${totalAmount.toStringAsFixed(0)}'),
                        const SizedBox(height: 6),
                        Text('Expenses: ${expenseCount.toInt()}'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Journey Expenses', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (expenses.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No expenses linked to this journey yet'),
                    ),
                  ),
                ...expenses.map((expense) {
                  final amount = (expense['amount'] ?? 0) as num;
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.receipt_long),
                      title: Text((expense['note'] ?? expense['category'] ?? 'Expense').toString()),
                      subtitle: Text(
                        '${(expense['category'] ?? 'Other').toString()} • ${_fmt(expense['date'])}',
                      ),
                      trailing: Text('INR ${amount.toStringAsFixed(0)}'),
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  String _fmt(dynamic dateValue) {
    if (dateValue == null) return '-';
    try {
      final d = DateTime.parse(dateValue.toString());
      return '${d.day}/${d.month}/${d.year}';
    } catch (_) {
      return dateValue.toString();
    }
  }
}
