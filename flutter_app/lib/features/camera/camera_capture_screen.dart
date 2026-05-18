import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../core/services/ocr_service.dart';
import '../../core/services/expense_service.dart';
import '../../core/services/api_service.dart';
import '../../core/models/expense_model.dart';
import 'package:intl/intl.dart';

class CameraCaptureScreen extends StatefulWidget {
  const CameraCaptureScreen({super.key});

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen> {
  final ImagePicker _picker = ImagePicker();
  final _formKey = GlobalKey<FormState>();
  
  File? _capturedImage;
  bool _isLoading = false;
  bool _isExtracting = false;
  String? _ocrError;

  final _amountCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController(text: 'Food');
  final _noteCtrl = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String? _selectedJourneyId;
  bool _journeysLoading = true;
  List<Map<String, dynamic>> _journeys = const [];

  final List<String> _categories = [
    'Food', 'Travel', 'Fuel', 'Entertainment', 'Utilities',
    'Hotel', 'Parking', 'Shopping', 'Health', 'Other'
  ];

  @override
  void initState() {
    super.initState();
    _loadJourneys();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _categoryCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_capturedImage == null) {
      return _buildCaptureScreen();
    }
    return _buildFormScreen();
  }

  Widget _buildCaptureScreen() => Center(
    child: SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.teal.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.camera_alt, size: 60, color: Colors.teal.shade700),
          ),
          const SizedBox(height: 24),
          Text(
            'Capture Receipt',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          const Text(
            'Take a photo of your receipt to\nauto-extract expense details',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: 200,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _takePhoto,
              icon: const Icon(Icons.camera_alt),
              label: const Text('Take Photo'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 200,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: _pickFromGallery,
              icon: const Icon(Icons.image),
              label: const Text('Pick from Gallery'),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildFormScreen() => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Form(
      key: _formKey,
      child: Column(
        children: [
          // Image preview
          Container(
            width: double.infinity,
            height: 250,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.teal),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              children: [
                Image.file(
                  _capturedImage!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: 250,
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => setState(() => _capturedImage = null),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // OCR Extract button
          if (!_isExtracting)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _extractFromOCR,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Auto-Extract with OCR'),
              ),
            ),
          if (_isExtracting)
            const SizedBox(
              width: double.infinity,
              child: LinearProgressIndicator(),
            ),
          if (_ocrError != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                border: Border.all(color: Colors.orange),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _ocrError!,
                style: TextStyle(color: Colors.orange.shade700, fontSize: 12),
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Amount (required)
          TextFormField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Amount *',
              prefixIcon: const Icon(Icons.currency_rupee),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              hintText: 'Enter amount in ₹',
            ),
            validator: (v) {
              if (v?.isEmpty ?? true) return 'Amount is required';
              if (double.tryParse(v!) == null) return 'Enter a valid amount';
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Category (required)
          DropdownButtonFormField<String>(
            value: _categoryCtrl.text,
            decoration: InputDecoration(
              labelText: 'Category *',
              prefixIcon: const Icon(Icons.category),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            items: _categories.map((c) => DropdownMenuItem(
              value: c,
              child: Text(c),
            )).toList(),
            onChanged: (v) => _categoryCtrl.text = v ?? 'Food',
            validator: (v) => (v?.isEmpty ?? true) ? 'Category is required' : null,
          ),
          const SizedBox(height: 16),

          // Journey (optional)
          DropdownButtonFormField<String>(
            value: _selectedJourneyId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Journey (optional)',
              prefixIcon: const Icon(Icons.map),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              helperText: _journeysLoading ? 'Loading journeys...' : null,
            ),
            items: [
              const DropdownMenuItem<String>(
                value: null,
                child: Text('No Journey'),
              ),
              ..._journeys.map(
                (j) => DropdownMenuItem<String>(
                  value: (j['_id'] ?? '').toString(),
                  child: Text((j['name'] ?? 'Unnamed Journey').toString()),
                ),
              ),
            ],
            onChanged: _journeysLoading
                ? null
                : (v) {
                    setState(() => _selectedJourneyId = v);
                  },
          ),
          const SizedBox(height: 16),

          // Date (required)
          TextFormField(
            readOnly: true,
            decoration: InputDecoration(
              labelText: 'Date *',
              prefixIcon: const Icon(Icons.calendar_today),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            controller: TextEditingController(
              text: DateFormat('dd/MM/yyyy').format(_selectedDate),
            ),
            onTap: _selectDate,
            validator: (_) => null,
          ),
          const SizedBox(height: 16),

          // Note (optional)
          TextFormField(
            controller: _noteCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Note (optional)',
              hintText: 'Add any additional details...',
              prefixIcon: const Icon(Icons.note),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Submit button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submitExpense,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save Expense'),
            ),
          ),
          const SizedBox(height: 12),

          // Cancel button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: () => setState(() => _capturedImage = null),
              child: const Text('Cancel'),
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> _takePhoto() async {
    try {
      final photo = await _picker.pickImage(source: ImageSource.camera);
      if (photo != null) {
        setState(() => _capturedImage = File(photo.path));
      }
    } catch (e) {
      _showError('Failed to capture photo: $e');
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final photo = await _picker.pickImage(source: ImageSource.gallery);
      if (photo != null) {
        setState(() => _capturedImage = File(photo.path));
      }
    } catch (e) {
      _showError('Failed to pick image: $e');
    }
  }

  Future<void> _extractFromOCR() async {
    if (_capturedImage == null) return;

    setState(() {
      _isExtracting = true;
      _ocrError = null;
    });

    try {
      final ocrService = OcrService();
      final result = await ocrService.extractReceiptData(_capturedImage!);

      if (mounted) {
        setState(() {
          // Pre-fill form with OCR results
          if (result['total_amount'] != null) {
            _amountCtrl.text = result['total_amount'].toString();
          }
          if (result['date'] != null) {
            try {
              _selectedDate = DateTime.parse(result['date']);
            } catch (_) {}
          }
          if (result['merchant_name'] != null) {
            _noteCtrl.text = result['merchant_name'] ?? '';
          }
          _isExtracting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _ocrError = 'OCR extraction failed: $e';
          _isExtracting = false;
        });
      }
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _submitExpense() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final amount = double.parse(_amountCtrl.text);
      final expense = ExpenseModel(
        amount: amount,
        category: _categoryCtrl.text,
        journeyId: _selectedJourneyId,
        note: _noteCtrl.text.isEmpty ? null : _noteCtrl.text,
        date: _selectedDate,
        imageLocalPath: _capturedImage?.path,
      );

      final expenseService = ExpenseService();
      final success = await expenseService.createExpense(
        expense: expense,
        imageFile: _capturedImage,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Expense saved!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
          // Reset form
          setState(() {
            _capturedImage = null;
            _amountCtrl.clear();
            _categoryCtrl.text = 'Food';
            _selectedJourneyId = null;
            _noteCtrl.clear();
            _selectedDate = DateTime.now();
            _isLoading = false;
          });
          if (Navigator.of(context).canPop()) {
            Navigator.pop(context, true);
          }
        } else {
          _showError('Failed to save expense');
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      _showError('Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadJourneys() async {
    setState(() => _journeysLoading = true);
    try {
      final response = await ApiService.instance.getJourneys(page: 1, limit: 100);
      final data = (response?['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      if (!mounted) return;
      setState(() {
        _journeys = data;
        _journeysLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _journeys = const [];
        _journeysLoading = false;
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
