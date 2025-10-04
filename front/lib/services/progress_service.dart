import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ProgressService {
  // 플랫폼별 서버 주소 목록
  static List<String> get serverUrls {
    if (kIsWeb) {
      return ['http://localhost:5002'];
    } else if (Platform.isAndroid) {
      return [
        'http://10.0.2.2:5002',
        'http://127.0.0.1:5002',
        'http://localhost:5002',
      ];
    } else {
      return ['http://localhost:5002'];
    }
  }

  // 여러 서버 주소 시도
  static Future<http.Response> _tryMultipleUrls(
    String endpoint,
    Map<String, String> headers, {
    String? body,
    String method = 'GET',
  }) async {
    for (String baseUrl in serverUrls) {
      try {
        http.Response response;
        if (method == 'GET') {
          response = await http
              .get(Uri.parse('$baseUrl$endpoint'), headers: headers)
              .timeout(const Duration(seconds: 5));
        } else {
          response = await http
              .post(
                Uri.parse('$baseUrl$endpoint'),
                headers: headers,
                body: body,
              )
              .timeout(const Duration(seconds: 5));
        }
        return response;
      } catch (e) {
        print('Failed to connect to $baseUrl: $e');
        continue;
      }
    }
    throw Exception('모든 서버 주소 연결 실패');
  }

  // 토큰 조회
  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  // 진도 조회
  static Future<Map<String, dynamic>> getProgress(String language) async {
    try {
      final token = await _getToken();
      if (token == null) {
        print('❌ 진도 조회 실패: 토큰 없음');
        return {'success': false, 'message': '로그인이 필요합니다.'};
      }

      print('📡 진도 조회 요청: /api/progress/$language');
      final response = await _tryMultipleUrls('/api/progress/$language', {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      });

      print('📥 진도 조회 응답 상태: ${response.statusCode}');
      print('📥 진도 조회 응답 body: ${response.body}');
      
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
        return {
          'success': true,
          'message': data['message'],
          'progress': data['progress'],
        };
      } else {
        return {
          'success': false,
          'message': data['error'] ?? '진도 업데이트에 실패했습니다.',
        };
      }
    } catch (e) {
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
      return {'success': false, 'message': '네트워크 오류가 발생했습니다: $e'};
    }
  }

  // 진도 초기화
  static Future<Map<String, dynamic>> resetProgress(String language) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': '로그인이 필요합니다.'};
      }

      final response = await _tryMultipleUrls(
        '/api/progress/$language/reset',
        {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({}),
        method: 'POST',
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? '진도가 초기화되었습니다.',
          'progress': data['progress'],
        };
      } else {
        return {
          'success': false,
          'message': data['error'] ?? '진도 초기화에 실패했습니다.',
        };
      }
    } catch (e) {
      return {'success': false, 'message': '네트워크 오류가 발생했습니다: $e'};
    }
  }
}
