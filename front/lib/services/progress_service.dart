import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProgressService {
  // 다중 서버 주소 시도 시스템
  static const List<String> _baseUrls = [
    'http://192.168.45.98:5002', // WiFi 연결 (노트북 실제 IP)
    'http://127.0.0.1:5002',     // USB 디버깅 (ADB 포트 포워딩)
    'http://10.0.2.2:5002',      // 에뮬레이터용
    'http://localhost:5002',     // USB 디버깅 대안
  ];

  static String? _workingBaseUrl;

  static Future<String> _getWorkingBaseUrl() async {
    if (_workingBaseUrl != null) {
      return _workingBaseUrl!;
    }

    // 웹 플랫폼에서는 localhost 사용
    if (kIsWeb) {
      _workingBaseUrl = 'http://localhost:5002';
      return _workingBaseUrl!;
    }

    // 각 서버 주소를 시도해서 작동하는 것 찾기
    for (String baseUrl in _baseUrls) {
      try {
        final response = await http.get(
          Uri.parse('$baseUrl/api/auth/health'),
        ).timeout(const Duration(seconds: 5));
        
        if (response.statusCode == 200) {
          _workingBaseUrl = baseUrl;
          print('✅ 작동하는 서버 주소: $baseUrl');
          return baseUrl;
        }
      } catch (e) {
        print('❌ 서버 연결 실패: $baseUrl - $e');
        continue;
      }
    }

    // 모든 주소가 실패하면 첫 번째 주소 사용
    _workingBaseUrl = _baseUrls.first;
    return _workingBaseUrl!;
  }

  // 토큰 가져오기
  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  // 다중 URL 시도 함수
  static Future<http.Response> _tryMultipleUrls(
    String endpoint,
    Map<String, String> headers, {
    String? body,
    String method = 'GET',
  }) async {
    final baseUrl = await _getWorkingBaseUrl();
    final uri = Uri.parse('$baseUrl$endpoint');

    switch (method.toUpperCase()) {
      case 'POST':
        return await http.post(uri, headers: headers, body: body);
      case 'PUT':
        return await http.put(uri, headers: headers, body: body);
      case 'DELETE':
        return await http.delete(uri, headers: headers);
      default:
        return await http.get(uri, headers: headers);
    }
  }

  // 진도 조회
  static Future<Map<String, dynamic>> getProgress(String language) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': '로그인이 필요합니다.'};
      }

      final response = await _tryMultipleUrls(
        '/api/progress/$language',
        {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        print('✅ 진도 조회 성공: ${data['progress']}');
        return {'success': true, 'progress': data['progress']};
      } else {
        print('❌ 진도 조회 실패: ${data['error']}');
        return {'success': false, 'message': data['error'] ?? '진도 조회에 실패했습니다.'};
      }
    } catch (e) {
      print('❌ 진도 조회 예외 발생: $e');
      return {'success': false, 'message': '네트워크 오류가 발생했습니다: $e'};
    }
  }

  // 진도 업데이트
  static Future<Map<String, dynamic>> updateProgress(
    String language,
    Map<String, dynamic> progressData,
  ) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': '로그인이 필요합니다.'};
      }

      final response = await _tryMultipleUrls(
        '/api/progress/$language/update',
        {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode(progressData),
        method: 'POST',
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        print('✅ 진도 업데이트 성공');
        return {'success': true, 'message': data['message']};
      } else {
        print('❌ 진도 업데이트 실패: ${data['error']}');
        return {
          'success': false,
          'message': data['error'] ?? '진도 업데이트에 실패했습니다.',
        };
      }
    } catch (e) {
      print('❌ 진도 업데이트 예외 발생: $e');
      return {'success': false, 'message': '네트워크 오류가 발생했습니다: $e'};
    }
  }

  // 인식 결과 저장
  static Future<Map<String, dynamic>> saveRecognition({
    required String language,
    required String recognizedText,
    double? confidenceScore,
    int? sessionDuration,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': '로그인이 필요합니다.'};
      }

      final response = await _tryMultipleUrls(
        '/api/recognition/save',
        {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({
          'language': language,
          'recognized_text': recognizedText,
          'confidence_score': confidenceScore,
          'session_duration': sessionDuration,
        }),
        method: 'POST',
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        return {
          'success': true,
          'message': data['message'],
          'recognition': data['recognition'],
        };
      } else {
        return {
          'success': false,
          'message': data['error'] ?? '인식 결과 저장에 실패했습니다.',
        };
      }
    } catch (e) {
      print('❌ 인식 결과 저장 예외 발생: $e');
      return {'success': false, 'message': '네트워크 오류가 발생했습니다: $e'};
    }
  }

  // 진도 초기화 (백엔드 API 연동)
  static Future<Map<String, dynamic>> resetProgress(String language) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': '로그인이 필요합니다.'};
      }

      final response = await _tryMultipleUrls(
        '/api/progress/$language/reset',
        {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        method: 'POST',
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        print('✅ 진도 초기화 성공');
        return {'success': true, 'message': data['message'] ?? '진도가 초기화되었습니다.'};
      } else {
        print('❌ 진도 초기화 실패: ${data['error']}');
        return {
          'success': false,
          'message': data['error'] ?? '진도 초기화에 실패했습니다.',
        };
      }
    } catch (e) {
      print('❌ 진도 초기화 예외 발생: $e');
      return {'success': false, 'message': '네트워크 오류가 발생했습니다: $e'};
    }
  }
}
