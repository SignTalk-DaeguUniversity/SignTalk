import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class RecognitionService {
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
              .post(Uri.parse('$baseUrl$endpoint'), headers: headers, body: body)
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

  // 인식 세션 시작
  static Future<Map<String, dynamic>> startRecognitionSession({
    String language = 'ksl',
    String mode = 'learning',
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': '로그인이 필요합니다.'};
      }

      final response = await _tryMultipleUrls(
        '/api/recognition/session/start',
        {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'language': language,
          'mode': mode,
        }),
        method: 'POST',
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        return {
          'success': true,
          'session_id': data['session_id'],
          'message': data['message'],
          'session_info': data['session_info'],
        };
      } else {
        return {
          'success': false,
          'message': data['error'] ?? '세션 시작에 실패했습니다.',
        };
      }
    } catch (e) {
      return {'success': false, 'message': '네트워크 오류가 발생했습니다: $e'};
    }
  }

  // 손모양 분석
  static Future<Map<String, dynamic>> analyzeHandShape({
    required String targetSign,
    String language = 'ksl',
    String? sessionId,
    String? imageData,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': '로그인이 필요합니다.'};
      }

      final response = await _tryMultipleUrls(
        '/api/recognition/analyze-hand',
        {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'target_sign': targetSign,
          'language': language,
          'session_id': sessionId,
          'image_data': imageData ?? '',
        }),
        method: 'POST',
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'analysis': data['analysis'],
          'message': data['message'],
          'session_updated': data['session_updated'],
        };
      } else {
        return {
          'success': false,
          'message': data['error'] ?? '손모양 분석에 실패했습니다.',
        };
      }
    } catch (e) {
      return {'success': false, 'message': '네트워크 오류가 발생했습니다: $e'};
    }
  }

  // 연습 모드
  static Future<Map<String, dynamic>> practiceMode({
    required String targetSign,
    String language = 'ksl',
    String? imageData,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': '로그인이 필요합니다.'};
      }

      final response = await _tryMultipleUrls(
        '/api/recognition/practice',
        {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'target_sign': targetSign,
          'language': language,
          'image_data': imageData ?? '',
        }),
        method: 'POST',
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'mode': data['mode'],
          'analysis': data['analysis'],
          'affects_progress': data['affects_progress'],
          'message': data['message'],
        };
      } else {
        return {
          'success': false,
          'message': data['error'] ?? '연습 모드 실행에 실패했습니다.',
        };
      }
    } catch (e) {
      return {'success': false, 'message': '네트워크 오류가 발생했습니다: $e'};
    }
  }

  // 학습 모드
  static Future<Map<String, dynamic>> learningMode({
    required String targetSign,
    String language = 'ksl',
    String? sessionId,
    String? imageData,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': '로그인이 필요합니다.'};
      }

      final response = await _tryMultipleUrls(
        '/api/recognition/learning',
        {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'target_sign': targetSign,
          'language': language,
          'session_id': sessionId,
          'image_data': imageData ?? '',
        }),
        method: 'POST',
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'mode': data['mode'],
          'analysis': data['analysis'],
          'affects_progress': data['affects_progress'],
          'progress_updated': data['progress_updated'],
          'message': data['message'],
        };
      } else {
        return {
          'success': false,
          'message': data['error'] ?? '학습 모드 실행에 실패했습니다.',
        };
      }
    } catch (e) {
      return {'success': false, 'message': '네트워크 오류가 발생했습니다: $e'};
    }
  }

  // 인식 통계 조회
  static Future<Map<String, dynamic>> getRecognitionStats({
    String language = 'ksl',
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': '로그인이 필요합니다.'};
      }

      final response = await _tryMultipleUrls(
        '/api/recognition/stats?language=$language',
        {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'total_attempts': data['total_attempts'],
          'average_confidence': data['average_confidence'],
          'recent_activity': data['recent_activity'],
        };
      } else {
        return {
          'success': false,
          'message': data['error'] ?? '통계 조회에 실패했습니다.',
        };
      }
    } catch (e) {
      return {'success': false, 'message': '네트워크 오류가 발생했습니다: $e'};
    }
  }
}
