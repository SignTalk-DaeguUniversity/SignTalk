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
          level = 1;  // 낱말퀴즈는 레벨 1 (가장 기초)
          questionType = 'character';
          break;
        case '초급':
          level = 2;
          questionType = 'syllable';
          break;
        case '중급':
          level = 3;
          questionType = 'syllable';
          break;
        case '고급':
          level = 4;
          questionType = 'word';
          break;
      }

      print('📝 퀴즈 결과 저장 시작');
      print('   - 모드: $mode (레벨 $level)');
      print('   - 총 문제: $totalProblems');
      print('   - 정답: $solvedProblems');
      print('   - 스킵: $skippedProblems');

      // 세션 ID 생성
      final sessionId = 'quiz_${DateTime.now().millisecondsSinceEpoch}';

      // 각 문제에 대한 퀴즈 결과 저장 (Quiz 테이블에 직접 저장)
      int successCount = 0;
      
      for (int i = 0; i < totalProblems; i++) {
        final isCorrect = i < solvedProblems;
        final isSkipped = i >= solvedProblems && i < (solvedProblems + skippedProblems);
        final userAnswer = isSkipped ? 'SKIPPED' : (isCorrect ? '정답' : '오답');
        
        try {
          final response = await http.post(
            Uri.parse('$baseUrl/api/quiz/ksl/submit'),
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
              'response_time': responseTime / totalProblems, // 평균 응답 시간
              'confidence_score': isCorrect ? 0.9 : 0.3,
            }),
          );

          if (response.statusCode == 201) {
            successCount++;
          } else {
            print('❌ 문제 ${i + 1} 저장 실패: ${response.statusCode}');
          }
        } catch (e) {
          print('❌ 문제 ${i + 1} 저장 오류: $e');
        }
      }

      if (successCount == totalProblems) {
        print('✅ 퀴즈 결과 저장 완료: $mode - ${accuracy.toStringAsFixed(1)}% ($successCount/$totalProblems)');
        return true;
      } else {
        print('⚠️ 퀴즈 결과 부분 저장: $successCount/$totalProblems');
        return successCount > 0; // 일부라도 저장되면 성공으로 처리
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
