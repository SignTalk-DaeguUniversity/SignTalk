import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'auth_service.dart';

class QuizService {
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

  // 퀴즈 결과 저장
  static Future<Map<String, dynamic>> submitQuiz({
    required String language,
    required int sessionId,
    required int level,
    required String questionType,
    required String question,
    required String correctAnswer,
    String? userAnswer,
    bool isCorrect = false,
    double? responseTime,
    double? confidenceScore,
    required String token,
  }) async {
    try {
      final baseUrl = await _getWorkingBaseUrl();

      final response = await http.post(
        Uri.parse('$baseUrl/api/learning/$language/quiz'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'session_id': sessionId,
          'level': level,
          'question_type': questionType,
          'question': question,
          'correct_answer': correctAnswer,
          'user_answer': userAnswer,
          'is_correct': isCorrect,
          'response_time': responseTime,
          'confidence_score': confidenceScore,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        return {
          'success': true,
          'quiz': data['quiz'],
          'message': data['message'],
        };
      } else {
        return {'success': false, 'message': data['error'] ?? 'Unknown error'};
      }
    } catch (e) {
      print('퀴즈 결과 저장 실패: $e');
      return {'success': false, 'message': '네트워크 오류: $e'};
    }
  }

  // 성취도 조회
  static Future<Map<String, dynamic>> getAchievements(String language) async {
    try {
      final baseUrl = await _getWorkingBaseUrl();
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/learning/$language/achievements'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {'success': true, 'achievements': data['achievements'] ?? {}};
      } else {
        return {
          'success': false,
          'error': 'Failed to load achievements: ${response.statusCode}',
        };
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ QuizService.getAchievements 실패: $e');
      }
      return {'success': false, 'error': e.toString()};
    }
  }

  // 토큰 가져오기
  static Future<String?> _getToken() async {
    final authService = AuthService();
    return await authService.getToken();
  }

  // 퀴즈 스킵 API (JWT 토큰 추가)
  static Future<Map<String, dynamic>> skipQuiz(
    String language,
    String quizType,
    String question, {
    String? sessionId,
    int? level,
    String? correctAnswer,
    int? responseTime,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'error': '로그인이 필요합니다.'};
      }

      final baseUrl = await _getWorkingBaseUrl();
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/quiz/$language/skip'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode({
              'session_id': sessionId ?? 'default_session',
              'level': level ?? 1,
              'question_type': quizType,
              'question': question,
              'correct_answer': correctAnswer ?? '',
              'response_time': responseTime ?? 0,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'message': data['message'] ?? 'Quiz skipped successfully',
          'quiz': data['quiz'],
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to skip quiz: ${response.statusCode}',
        };
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ QuizService.skipQuiz 실패: $e');
      }
      return {'success': false, 'error': e.toString()};
    }
  }

  // 퀴즈 레벨 조회 API (JWT 토큰 추가)
  static Future<Map<String, dynamic>> getQuizLevels(String language) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'error': '로그인이 필요합니다.'};
      }

      final baseUrl = await _getWorkingBaseUrl();
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/quiz/$language/levels'),
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
          'language': data['language'],
          'levels': data['levels'] ?? []
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to get quiz levels: ${response.statusCode}',
        };
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ QuizService.getQuizLevels 실패: $e');
      }
      return {'success': false, 'error': e.toString()};
    }
  }

  // 퀴즈 생성 API (JWT 토큰 추가)
  static Future<Map<String, dynamic>> generateQuiz(
    String language, {
    int? level,
    String? mode,
    int? count,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'error': '로그인이 필요합니다.'};
      }

      final baseUrl = await _getWorkingBaseUrl();
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/quiz/$language/generate'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode({
              'level': level ?? 1,
              'mode': mode ?? 'recognition',
              'count': count ?? 5,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'level': data['level'],
          'mode': data['mode'],
          'total_questions': data['total_questions'],
          'questions': data['questions'] ?? [],
          'level_config': data['level_config'],
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to generate quiz: ${response.statusCode}',
        };
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ QuizService.generateQuiz 실패: $e');
      }
      return {'success': false, 'error': e.toString()};
    }
  }

  // 퀴즈 통계 조회 API (JWT 토큰 추가)
  static Future<Map<String, dynamic>> getQuizStatistics(String language, {int? level}) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'error': '로그인이 필요합니다.'};
      }

      final baseUrl = await _getWorkingBaseUrl();
      String url = '$baseUrl/api/quiz/$language/statistics';
      if (level != null) {
        url += '?level=$level';
      }
      
      final response = await http
          .get(
            Uri.parse(url),
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
          'statistics': data['statistics'] ?? {},
          'level_breakdown': data['level_breakdown'] ?? [],
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to get quiz statistics: ${response.statusCode}',
        };
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ QuizService.getQuizStatistics 실패: $e');
      }
      return {'success': false, 'error': e.toString()};
    }
  }

  // 퀴즈 답안 제출 API (새로운 백엔드 API 연동)
  static Future<Map<String, dynamic>> submitQuizAnswer({
    required String language,
    required String sessionId,
    required int level,
    required String questionType,
    required String question,
    required String correctAnswer,
    required String userAnswer,
    int? responseTime,
    double? confidenceScore,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'error': '로그인이 필요합니다.'};
      }

      final baseUrl = await _getWorkingBaseUrl();
      
      print('📝 퀴즈 답안 제출: $question -> $userAnswer (정답: $correctAnswer)');
      
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/quiz/$language/submit'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode({
              'session_id': sessionId,
              'level': level,
              'question_type': questionType,
              'question': question,
              'correct_answer': correctAnswer,
              'user_answer': userAnswer,
              'response_time': responseTime ?? 0,
              'confidence_score': confidenceScore ?? 0.0,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        
        print('✅ 퀴즈 답안 제출 성공: ${data['is_correct'] ? "정답" : "오답"}');
        
        return {
          'success': true,
          'is_correct': data['is_correct'],
          'message': data['message'],
          'quiz': data['quiz'],
        };
      } else {
        final data = json.decode(response.body);
        print('❌ 퀴즈 답안 제출 실패: ${data['error']}');
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to submit quiz answer',
        };
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ QuizService.submitQuizAnswer 실패: $e');
      }
      return {'success': false, 'error': e.toString()};
    }
  }

  // 퀴즈 세션 시작 (퀴즈 답안 제출을 위한 세션 ID 생성)
  static Future<Map<String, dynamic>> startQuizSession({
    required String language,
    required String quizType,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'error': '로그인이 필요합니다.'};
      }

      // 세션 ID 생성 (현재 시간 기반)
      final sessionId = 'quiz_${DateTime.now().millisecondsSinceEpoch}';
      
      print('🎯 퀴즈 세션 시작: $sessionId ($quizType)');
      
      return {
        'success': true,
        'session_id': sessionId,
        'quiz_type': quizType,
        'language': language,
        'start_time': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ QuizService.startQuizSession 실패: $e');
      }
      return {'success': false, 'error': e.toString()};
    }
  }

  // 퀴즈 세션 종료 및 결과 요약
  static Future<Map<String, dynamic>> endQuizSession({
    required String sessionId,
    required int totalQuestions,
    required int correctAnswers,
    required int totalTime,
  }) async {
    try {
      final accuracy = totalQuestions > 0 ? (correctAnswers / totalQuestions * 100) : 0.0;
      
      print('🏁 퀴즈 세션 종료: $sessionId');
      print('   - 총 문제: $totalQuestions');
      print('   - 정답: $correctAnswers');
      print('   - 정확도: ${accuracy.toStringAsFixed(1)}%');
      print('   - 소요시간: ${totalTime}초');
      
      return {
        'success': true,
        'session_id': sessionId,
        'total_questions': totalQuestions,
        'correct_answers': correctAnswers,
        'accuracy': accuracy,
        'total_time': totalTime,
        'end_time': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ QuizService.endQuizSession 실패: $e');
      }
      return {'success': false, 'error': e.toString()};
    }
  }

  // 모드별 퀴즈 생성 API (새로운 백엔드 API 연동)
  static Future<Map<String, dynamic>> generateQuizByMode({
    required String language,
    required String mode, // '낱말퀴즈', '초급', '중급', '고급'
    int? count,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'error': '로그인이 필요합니다.'};
      }

      final baseUrl = await _getWorkingBaseUrl();
      
      print('🎲 모드별 퀴즈 생성: $mode (개수: ${count ?? "기본"})');
      
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/quiz/$language/mode/$mode/generate'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode({
              'count': count,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        print('✅ 모드별 퀴즈 생성 성공: ${data['total_problems']}개 문제');
        
        return {
          'success': true,
          'mode': data['mode'],
          'description': data['description'],
          'total_problems': data['total_problems'],
          'problems': data['problems'],
        };
      } else {
        final data = json.decode(response.body);
        print('❌ 모드별 퀴즈 생성 실패: ${data['error']}');
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to generate quiz by mode',
        };
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ QuizService.generateQuizByMode 실패: $e');
      }
      return {'success': false, 'error': e.toString()};
    }
  }

  // 퀴즈 모드 목록 조회
  static Future<Map<String, dynamic>> getAvailableQuizModes(String language) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'error': '로그인이 필요합니다.'};
      }

      // 현재 지원하는 퀴즈 모드들
      final availableModes = {
        '낱말퀴즈': {
          'description': '자음과 모음을 개별적으로 학습',
          'difficulty': 'beginner',
          'default_count': 40,
        },
        '초급': {
          'description': '받침 없는 글자 학습',
          'difficulty': 'easy',
          'default_count': 10,
        },
        '중급': {
          'description': '받침 있는 글자 학습',
          'difficulty': 'medium',
          'default_count': 10,
        },
        '고급': {
          'description': '단어 및 문장 학습',
          'difficulty': 'hard',
          'default_count': 10,
        },
      };

      print('📋 사용 가능한 퀴즈 모드: ${availableModes.keys.join(", ")}');

      return {
        'success': true,
        'language': language,
        'modes': availableModes,
        'total_modes': availableModes.length,
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ QuizService.getAvailableQuizModes 실패: $e');
      }
      return {'success': false, 'error': e.toString()};
    }
  }

  // 퀴즈 문제 형식 변환 (백엔드 → 앱 형식)
  static List<Map<String, String>> convertProblemsToAppFormat(
    List<dynamic> backendProblems,
    String mode,
  ) {
    try {
      return backendProblems.map<Map<String, String>>((problem) {
        if (problem is Map<String, dynamic>) {
          return {
            'type': mode,
            'question': problem['question']?.toString() ?? '',
            'description': problem['description']?.toString() ?? '$mode 문제입니다',
            'difficulty': problem['difficulty']?.toString() ?? 'normal',
            'category': problem['category']?.toString() ?? mode,
          };
        } else if (problem is String) {
          return {
            'type': mode,
            'question': problem,
            'description': '$mode 문제입니다',
            'difficulty': 'normal',
            'category': mode,
          };
        } else {
          return {
            'type': mode,
            'question': problem.toString(),
            'description': '$mode 문제입니다',
            'difficulty': 'normal',
            'category': mode,
          };
        }
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        print('❌ 퀴즈 문제 형식 변환 실패: $e');
      }
      return [];
    }
  }
}
