import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import 'journey_detail_screen.dart';

class JourneysScreen extends StatefulWidget {
  const JourneysScreen({super.key});

  @override
  State<JourneysScreen> createState() => _JourneysScreenState();
}

class _JourneysScreenState extends State<JourneysScreen> {
  late Future<Map<String, dynamic>> _journeysFuture;
  bool _creatingJourney = false;

  @override
  void initState() {
    super.initState();
    _loadJourneys();
  }

  void _loadJourneys() {
    _journeysFuture =
        ApiService.instance.getJourneys(page: 1, limit: 20).then((v) => v ?? {'data': []});
  }

  @override
  Widget build(BuildContext context) {
    final isNested = Navigator.canPop(context);
    return Scaffold(
      appBar: isNested ? AppBar(title: const Text('Journeys')) : null,
      body: FutureBuilder<Map<String, dynamic>>(
        future: _journeysFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final journeys =
              (snapshot.data?['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          if (journeys.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('No journeys found. Create one to start tracking!'),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => setState(() => _loadJourneys()),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: journeys.length,
              itemBuilder: (context, index) {
                final journey = journeys[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: GestureDetector(
                    onTap: () {
                      final journeyId = (journey['_id'] ?? '').toString();
                      if (journeyId.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Invalid journey item')),
                        );
                        return;
                      }
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => JourneyDetailScreen(
                            journeyId: journeyId,
                            title: (journey['name'] ?? 'Journey').toString(),
                          ),
                        ),
                      );
                    },
                    child: Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.teal.shade100,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.flight,
                                    color: Colors.teal,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        journey['name'] ?? 'Journey',
                                        style: const TextStyle(
                                            fontSize: 18, fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        _formatDuration(
                                            journey['startDate'], journey['endDate']),
                                        style:
                                            const TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                                Chip(
                                  label: Text(_getDurationText(
                                      journey['startDate'], journey['endDate'])),
                                  backgroundColor: Colors.teal.shade50,
                                  labelStyle: const TextStyle(color: Colors.teal),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Total Expenses',
                                  style:
                                      TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                ),
                                Text(
                                  '₹${((journey['totalAmount'] ?? 0) as num).toStringAsFixed(0)}',
                                  style: const TextStyle(
                                      fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: !isNested
          ? FloatingActionButton(
              onPressed: _creatingJourney ? null : _showCreateJourneyDialog,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Future<void> _showCreateJourneyDialog() async {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final descriptionCtrl = TextEditingController();
    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now().add(const Duration(days: 1));

    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Create Journey'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Journey Name',
                          hintText: 'Trip to Goa',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Journey name is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: descriptionCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Description (optional)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.date_range),
                        title: const Text('Start Date'),
                        subtitle: Text(
                          '${startDate.day}/${startDate.month}/${startDate.year}',
                        ),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: dialogContext,
                            initialDate: startDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setDialogState(() {
                              startDate = picked;
                              if (endDate.isBefore(startDate)) {
                                endDate = startDate;
                              }
                            });
                          }
                        },
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.event),
                        title: const Text('End Date'),
                        subtitle: Text(
                          '${endDate.day}/${endDate.month}/${endDate.year}',
                        ),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: dialogContext,
                            initialDate: endDate,
                            firstDate: startDate,
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setDialogState(() => endDate = picked);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    if (endDate.isBefore(startDate)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('End date cannot be before start date')),
                      );
                      return;
                    }
                    Navigator.pop(dialogContext, true);
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );

    if (created != true) {
      nameCtrl.dispose();
      descriptionCtrl.dispose();
      return;
    }

    setState(() => _creatingJourney = true);
    try {
      await ApiService.instance.post('/journeys', {
        'name': nameCtrl.text.trim(),
        'description': descriptionCtrl.text.trim(),
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'tags': <String>[],
      });

      if (!mounted) return;
      setState(() => _loadJourneys());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Journey created successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create journey: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _creatingJourney = false);
      }
      nameCtrl.dispose();
      descriptionCtrl.dispose();
    }
  }

  String _formatDuration(dynamic start, dynamic end) {
    if (start == null || end == null) return '';
    try {
      final startDate = DateTime.parse(start.toString());
      final endDate = DateTime.parse(end.toString());
      return '${startDate.day}/${startDate.month} - ${endDate.day}/${endDate.month}';
    } catch (_) {
      return '';
    }
  }

  String _getDurationText(dynamic start, dynamic end) {
    if (start == null || end == null) return '0 days';
    try {
      final startDate = DateTime.parse(start.toString());
      final endDate = DateTime.parse(end.toString());
      final days = endDate.difference(startDate).inDays + 1;
      return '$days day${days == 1 ? '' : 's'}';
    } catch (_) {
      return '0 days';
    }
  }
}
