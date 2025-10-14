import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RecognitionSessionService {
  // 다중 서버 주소 시도 시스템
  static const List<String> _baseUrls = [
    'http://10.0.2.2:5002', // 안드로이드 에뮬레이터용
    'http://127.0.0.1:5002', // 로컬호스트
    'http://localhost:5002', // 백업
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
        final response = await http
            .get(Uri.parse('$baseUrl/api/auth/health'))
            .timeout(const Duration(seconds: 5));

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

  // 인식 세션 시작
  static Future<Map<String, dynamic>> startRecognitionSession({
    required String language,
    required String mode, // 'practice', 'learning', 'quiz'
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'error': '로그인이 필요합니다.'};
      }

      final baseUrl = await _getWorkingBaseUrl();
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/recognition/session/start'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode({
              'language': language,
              'mode': mode,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'session_id': data['session_id'],
          'message': data['message'],
          'session_info': data['session_info'],
        };
      } else {
        final data = json.decode(response.body);
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to start recognition session',
        };
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ RecognitionSessionService.startRecognitionSession 실패: $e');
      }
      return {'success': false, 'error': e.toString()};
    }
  }

  // 인식 세션 종료
  static Future<Map<String, dynamic>> endRecognitionSession(String sessionId) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'error': '로그인이 필요합니다.'};
      }

      final baseUrl = await _getWorkingBaseUrl();
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/recognition/session/$sessionId/end'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'message': data['message'],
          'session_summary': data['session_summary'],
        };
      } else {
        final data = json.decode(response.body);
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to end recognition session',
        };
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ RecognitionSessionService.endRecognitionSession 실패: $e');
      }
      return {'success': false, 'error': e.toString()};
    }
  }

  // 학습 세션 시작
  static Future<Map<String, dynamic>> startLearningSession({
    required String language,
    required int level,
    required String lessonType,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'error': '로그인이 필요합니다.'};
      }

      final baseUrl = await _getWorkingBaseUrl();
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/learning/$language/session/start'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode({
              'level': level,
              'lesson_type': lessonType,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'message': data['message'],
          'session': data['session'],
        };
      } else {
        final data = json.decode(response.body);
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to start learning session',
        };
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ RecognitionSessionService.startLearningSession 실패: $e');
      }
      return {'success': false, 'error': e.toString()};
    }
  }

  // 학습 세션 종료
  static Future<Map<String, dynamic>> endLearningSession({
    required String language,
    required int sessionId,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'error': '로그인이 필요합니다.'};
      }

      final baseUrl = await _getWorkingBaseUrl();
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/learning/$language/session/$sessionId/end'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'message': data['message'],
          'session': data['session'],
        };
      } else {
        final data = json.decode(response.body);
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to end learning session',
        };
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ RecognitionSessionService.endLearningSession 실패: $e');
      }
      return {'success': false, 'error': e.toString()};
    }
  }

  // 손모양 분석
  static Future<Map<String, dynamic>> analyzeHandShape({
    required String sessionId,
    required String targetSign,
    String? imageData,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'error': '로그인이 필요합니다.'};
      }

      final baseUrl = await _getWorkingBaseUrl();
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/recognition/analyze-hand'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode({
              'session_id': sessionId,
              'target_sign': targetSign,
              'image_data': imageData,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'analysis': data['analysis'],
          'feedback': data['feedback'],
          'accuracy_score': data['accuracy_score'],
        };
      } else {
        final data = json.decode(response.body);
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to analyze hand shape',
        };
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ RecognitionSessionService.analyzeHandShape 실패: $e');
      }
      return {'success': false, 'error': e.toString()};
    }
  }
}
