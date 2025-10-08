import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'auth_service.dart';

class LearningSessionService {
  // 다중 서버 주소 시도 시스템
  static const List<String> _baseUrls = [
    'http://10.0.2.2:5002',      // 에뮬레이터용 (우선순위)
    'http://127.0.0.1:5002',     // USB 디버깅 (ADB 포트 포워딩)
    'http://192.168.45.98:5002', // WiFi 연결 (노트북 실제 IP)
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
          print('✅ 작동하는 서버 발견: $baseUrl');
          return baseUrl;
        }
      } catch (e) {
        print('❌ 서버 연결 실패: $baseUrl - $e');
        continue;
      }
    }
    
    // 모든 서버가 실패하면 첫 번째 주소 사용
    _workingBaseUrl = _baseUrls.first;
    return _workingBaseUrl!;
  }

  /// 학습 세션 시작
  static Future<Map<String, dynamic>?> startLearningSession({
    required String language,
    required int level,
    required String lessonType,
  }) async {
    try {
      final baseUrl = await _getWorkingBaseUrl();
      final authService = AuthService();
      final token = await authService.getToken();
      
      if (token == null) {
        print('❌ 토큰이 없습니다');
        return null;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/learning/$language/session/start'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'level': level,
          'lesson_type': lessonType,
        }),
      ).timeout(const Duration(seconds: 10));

      print('📤 학습 세션 시작 요청: $language, level: $level, type: $lessonType');
      print('📥 응답 상태: ${response.statusCode}');
      print('📥 응답 내용: ${response.body}');

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        print('✅ 학습 세션 시작 성공: ${data['session']['id']}');
        return data;
      } else {
        print('❌ 학습 세션 시작 실패: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ 학습 세션 시작 오류: $e');
      return null;
    }
  }

  /// 학습 세션 종료
  static Future<Map<String, dynamic>?> endLearningSession({
    required String language,
    required int sessionId,
    required int duration,
    required int totalAttempts,
    required int correctAttempts,
    required bool completed,
  }) async {
    try {
      final baseUrl = await _getWorkingBaseUrl();
      final authService = AuthService();
      final token = await authService.getToken();
      
      if (token == null) {
        print('❌ 토큰이 없습니다');
        return null;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/learning/$language/session/$sessionId/end'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'duration': duration,
          'total_attempts': totalAttempts,
          'correct_attempts': correctAttempts,
          'completed': completed,
        }),
      ).timeout(const Duration(seconds: 10));

      print('📤 학습 세션 종료 요청: session $sessionId');
      print('📥 응답 상태: ${response.statusCode}');
      print('📥 응답 내용: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ 학습 세션 종료 성공');
        return data;
      } else {
        print('❌ 학습 세션 종료 실패: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ 학습 세션 종료 오류: $e');
      return null;
    }
  }

  /// 커리큘럼 조회
  static Future<List<dynamic>?> getCurriculum({
    required String language,
    required int level,
  }) async {
    try {
      final baseUrl = await _getWorkingBaseUrl();
      final authService = AuthService();
      final token = await authService.getToken();
      
      if (token == null) {
        print('❌ 토큰이 없습니다');
        return null;
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/learning/$language/curriculum?level=$level'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      print('📤 커리큘럼 조회 요청: $language, level: $level');
      print('📥 응답 상태: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ 커리큘럼 조회 성공: ${data['total_lessons']}개 레슨');
        return data['curriculum'];
      } else {
        print('❌ 커리큘럼 조회 실패: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ 커리큘럼 조회 오류: $e');
      return null;
    }
  }
}
