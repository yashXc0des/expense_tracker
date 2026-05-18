import 'dart:io';
import 'package:dio/dio.dart';
import 'api_service.dart';

class OcrService {
  static final OcrService _instance = OcrService._internal();
  late Dio _dio;
  final ApiService _api = ApiService.instance;

  factory OcrService() {
    return _instance;
  }

  OcrService._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiService.instance.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ));
  }

  /// Extract receipt data from image using OCR
  Future<Map<String, dynamic>> extractReceiptData(File imageFile) async {
    try {
      print('[OCR] Extracting data from: ${imageFile.path}');

      final token = await _api.getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Authentication required for OCR');
      }

      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(
          imageFile.path,
          filename: imageFile.path.split('/').last,
        ),
      });

      final response = await _dio.post(
        '/expenses/extract',
        data: formData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      if (response.statusCode == 200) {
        print('[OCR] Success: ${response.data}');
        return response.data as Map<String, dynamic>;
      } else {
        throw Exception('OCR extraction failed: ${response.statusCode}');
      }
    } catch (e) {
      print('[OCR] Error: $e');
      rethrow;
    }
  }

  /// Health check for OCR service
  Future<bool> healthCheck() async {
    try {
      final response = await _dio.get('/health'.replaceAll('/api/health', '/health'));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
