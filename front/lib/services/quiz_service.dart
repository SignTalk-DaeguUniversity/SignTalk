import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class QuizService {
  // 다중 서버 주소 시도 시스템
  static const List<String> _baseUrls = [
    'http://10.0.2.2:5000',  // 안드로이드 에뮬레이터용
    'http://127.0.0.1:5000', // 로컬호스트
    'http://localhost:5000', // 백업
  ];

  static String? _workingBaseUrl;

  static Future<String> _getWorkingBaseUrl() async {
    if (_workingBaseUrl != null) {
      return _workingBaseUrl!;
    }

    // 웹 플랫폼에서는 localhost 사용
    if (kIsWeb) {
      _workingBaseUrl = 'http://localhost:5000';
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
        return {
          'success': false,
          'message': data['error'] ?? 'Unknown error',
        };
      }
    } catch (e) {
      print('퀴즈 결과 저장 실패: $e');
      return {
        'success': false,
        'message': '네트워크 오류: $e',
      };
    }
  }

  // 성취도 및 기본 통계 조회 (기존 API 활용)
  static Future<Map<String, dynamic>> getAchievements({
    required String language,
    required String token,
  }) async {
    try {
      final baseUrl = await _getWorkingBaseUrl();
      print('🌐 퀴즈 API 호출: $baseUrl/api/learning/$language/achievements');
      
      final response = await http.get(
        Uri.parse('$baseUrl/api/learning/$language/achievements'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      print('📡 응답 상태: ${response.statusCode}');
      print('📄 응답 본문: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'achievements': data['achievements'] ?? [],
          'statistics': data['statistics'] ?? {},
        };
      } else if (response.statusCode == 404) {
        // API 엔드포인트가 없는 경우 - 빈 데이터 반환
        print('⚠️ 퀴즈 API 엔드포인트 없음 - 빈 데이터 반환');
        return {
          'success': true,
          'achievements': [],
          'statistics': {'total_achievements': 0, 'total_completed_sessions': 0, 'average_accuracy': 0.0},
        };
      } else {
        final data = jsonDecode(response.body);
        return {
          'success': false,
          'message': data['error'] ?? 'HTTP ${response.statusCode}',
        };
      }
    } catch (e) {
      print('💥 성취도 조회 실패: $e');
      // 네트워크 오류 시 빈 데이터 반환
      return {
        'success': true,
        'achievements': [],
        'statistics': {'total_achievements': 0, 'total_completed_sessions': 0, 'average_accuracy': 0.0},
      };
    }
  }


  // 퀴즈 통계 분석 (프론트엔드에서 계산)
  static Map<String, dynamic> analyzeQuizStatistics(List<dynamic> achievements, Map<String, dynamic> statistics) {
    // 기본 통계
    final totalSessions = statistics['total_completed_sessions'] ?? 0;
    final averageAccuracy = statistics['average_accuracy'] ?? 0.0;
    final totalAchievements = statistics['total_achievements'] ?? 0;

    // 데이터가 없으면 빈 통계 반환
    if (totalSessions == 0 && achievements.isEmpty) {
      return {
        'total_sessions': 0,
        'average_accuracy': 0.0,
        'total_achievements': 0,
        'level_statistics': {},
        'mode_statistics': _generateEmptyModeStatistics(),
        'recent_performance': {
          'trend': 'stable',
          'recent_accuracy': 0.0,
          'improvement': 0.0,
        },
      };
    }

    // 퀴즈 모드별 통계 (실제 데이터 기반으로 생성)
    Map<String, Map<String, dynamic>> modeStatistics = _generateModeStatistics(achievements, totalSessions);

    return {
      'total_sessions': totalSessions,
      'average_accuracy': averageAccuracy,
      'total_achievements': totalAchievements,
      'level_statistics': {},
      'mode_statistics': modeStatistics,
      'recent_performance': _calculateRecentPerformance(achievements),
    };
  }

  // 빈 모드 통계 생성
  static Map<String, Map<String, dynamic>> _generateEmptyModeStatistics() {
    return {
      '낱말퀴즈': {
        'attempts': 0,
        'sessions': [],
        'has_data': false,
      },
      '초급': {
        'attempts': 0,
        'sessions': [],
        'has_data': false,
      },
      '중급': {
        'attempts': 0,
        'sessions': [],
        'has_data': false,
      },
      '고급': {
        'attempts': 0,
        'sessions': [],
        'has_data': false,
      },
    };
  }

  // 실제 데이터 기반 모드 통계 생성
  static Map<String, Map<String, dynamic>> _generateModeStatistics(List<dynamic> achievements, int totalSessions) {
    print('🔍 성취도 데이터 분석 중...');
    print('📊 총 성취도: ${achievements.length}개');
    print('📈 총 세션: $totalSessions개');
    
    // 실제 데이터가 있는지 확인
    if (achievements.isNotEmpty || totalSessions > 0) {
      print('✅ 실제 퀴즈 데이터 발견! 분석 중...');
      
      // 실제 achievements 데이터를 분석하여 모드별로 분류
      Map<String, List<Map<String, dynamic>>> modeData = {
        '낱말퀴즈': [],
        '초급': [],
        '중급': [],
        '고급': [],
      };
      
      // achievements 데이터를 모드별로 분류
      for (var achievement in achievements) {
        final level = achievement['level'] ?? 1;
        final achievementType = achievement['achievement_type'] ?? '';
        final value = achievement['value'] ?? 0.0;
        
        String mode = '낱말퀴즈'; // 기본값
        if (achievementType.contains('level_complete')) {
          if (level == 1) mode = '초급';
          else if (level == 2 || level == 3) mode = '중급';
          else if (level >= 4) mode = '고급';
        }
        
        modeData[mode]!.add({
          'accuracy': value,
          'date': achievement['earned_at'] ?? DateTime.now().toIso8601String(),
        });
      }
      
      // 모드별 통계 생성
      Map<String, Map<String, dynamic>> result = {};
      
      modeData.forEach((modeName, data) {
        if (data.isNotEmpty) {
          List<Map<String, dynamic>> sessions = [];
          
          for (int i = 0; i < data.length; i++) {
            final accuracy = data[i]['accuracy'];
            final totalProblems = 10; // 기본 문제 수
            final solvedProblems = (totalProblems * accuracy / 100).round();
            final skippedProblems = totalProblems - solvedProblems;
            
            sessions.add({
              'session_number': i + 1,
              'solved_problems': solvedProblems,
              'total_problems': totalProblems,
              'accuracy': accuracy,
              'skipped_problems': skippedProblems,
              'date': data[i]['date'],
            });
          }
          
          result[modeName] = {
            'attempts': data.length,
            'sessions': sessions,
            'has_data': true,
          };
          
          print('📝 $modeName: ${data.length}회 시도');
        } else {
          result[modeName] = {
            'attempts': 0,
            'sessions': [],
            'has_data': false,
          };
        }
      });
      
      return result;
    }
    
    print('❌ 퀴즈 데이터 없음 - 빈 통계 반환');
    return _generateEmptyModeStatistics();
  }


  // 최근 성과 계산
  static Map<String, dynamic> _calculateRecentPerformance(List<dynamic> achievements) {
    if (achievements.isEmpty) {
      return {
        'trend': 'stable',
        'recent_accuracy': 0.0,
        'improvement': 0.0,
      };
    }

    // 최근 5개 성취도 분석
    final recentAchievements = achievements.take(5).toList();
    double recentSum = 0;
    
    for (var achievement in recentAchievements) {
      recentSum += achievement['value'] ?? 0.0;
    }
    
    double recentAverage = recentSum / recentAchievements.length;
    
    // 전체 평균과 비교
    double totalSum = 0;
    for (var achievement in achievements) {
      totalSum += achievement['value'] ?? 0.0;
    }
    double totalAverage = totalSum / achievements.length;
    
    double improvement = recentAverage - totalAverage;
    
    return {
      'trend': improvement > 5 ? 'improving' : improvement < -5 ? 'declining' : 'stable',
      'recent_accuracy': recentAverage,
      'improvement': improvement,
    };
  }
}
