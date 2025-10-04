import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'auth_service.dart';

class QuizResultService {
  // 다중 서버 주소 시도 시스템
  static const List<String> _baseUrls = [
    'http://10.0.2.2:5002',  // 안드로이드 에뮬레이터용
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

  // 퀴즈 결과 저장 (퀴즈 완료 시 호출)
  static Future<bool> saveQuizResult({
    required String mode, // '낱말퀴즈', '초급', '중급', '고급'
    required int totalProblems,
    required int solvedProblems,
    required int skippedProblems,
    required double accuracy,
    required int responseTime, // 초 단위
  }) async {
    try {
      final authService = AuthService();
      final token = await authService.getToken();
      
      if (token == null) {
        print('❌ 토큰이 없어서 퀴즈 결과 저장 불가');
        return false;
      }

      final baseUrl = await _getWorkingBaseUrl();
      
      // 모드에 따른 레벨 매핑
      int level = 1;
      String questionType = 'recognition';
      
      switch (mode) {
        case '낱말퀴즈':
          level = 1;
          questionType = 'translation';
          break;
        case '초급':
          level = 1;
          questionType = 'recognition';
          break;
        case '중급':
          level = 2;
          questionType = 'recognition';
          break;
        case '고급':
          level = 3;
          questionType = 'recognition';
          break;
      }

      // 학습 세션 시작
      final sessionResponse = await http.post(
        Uri.parse('$baseUrl/api/learning/ksl/session/start'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'level': level,
          'lesson_type': questionType,
        }),
      );

      if (sessionResponse.statusCode != 201) {
        print('❌ 학습 세션 시작 실패: ${sessionResponse.statusCode}');
        return false;
      }

      final sessionData = jsonDecode(sessionResponse.body);
      final sessionId = sessionData['session']['id'];

      print('✅ 학습 세션 시작: $sessionId');

      // 각 문제에 대한 퀴즈 결과 저장
      for (int i = 0; i < totalProblems; i++) {
        final isCorrect = i < solvedProblems;
        final userAnswer = isCorrect ? '정답' : (i < solvedProblems + skippedProblems ? null : '오답');
        
        await http.post(
          Uri.parse('$baseUrl/api/learning/ksl/quiz'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'session_id': sessionId,
            'level': level,
            'question_type': questionType,
            'question': '문제 ${i + 1}',
            'correct_answer': '정답',
            'user_answer': userAnswer,
            'is_correct': isCorrect,
            'response_time': responseTime / totalProblems, // 평균 응답 시간
            'confidence_score': isCorrect ? 0.9 : 0.3,
          }),
        );
      }

      // 학습 세션 종료
      final endResponse = await http.post(
        Uri.parse('$baseUrl/api/learning/ksl/session/$sessionId/end'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'duration': responseTime,
          'total_attempts': totalProblems,
          'correct_attempts': solvedProblems,
          'completed': true,
        }),
      );

      if (endResponse.statusCode == 200) {
        print('✅ 퀴즈 결과 저장 완료: $mode - ${accuracy.toStringAsFixed(1)}%');
        return true;
      } else {
        print('❌ 학습 세션 종료 실패: ${endResponse.statusCode}');
        return false;
      }

    } catch (e) {
      print('💥 퀴즈 결과 저장 실패: $e');
      return false;
    }
  }

  // 테스트용 퀴즈 결과 저장
  static Future<void> saveTestQuizResults() async {
    print('🧪 테스트 퀴즈 결과 저장 중...');
    
    // 낱말퀴즈 결과
    await saveQuizResult(
      mode: '낱말퀴즈',
      totalProblems: 10,
      solvedProblems: 8,
      skippedProblems: 2,
      accuracy: 80.0,
      responseTime: 120,
    );

    await Future.delayed(const Duration(seconds: 1));

    await saveQuizResult(
      mode: '낱말퀴즈',
      totalProblems: 10,
      solvedProblems: 9,
      skippedProblems: 1,
      accuracy: 90.0,
      responseTime: 100,
    );

    // 초급 결과
    await Future.delayed(const Duration(seconds: 1));

    await saveQuizResult(
      mode: '초급',
      totalProblems: 8,
      solvedProblems: 6,
      skippedProblems: 2,
      accuracy: 75.0,
      responseTime: 90,
    );

    print('✅ 테스트 퀴즈 결과 저장 완료!');
  }
}
