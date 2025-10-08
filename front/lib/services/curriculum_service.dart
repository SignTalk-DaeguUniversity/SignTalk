import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class CurriculumService {
  // 플랫폼별 서버 주소 목록
  static List<String> get serverUrls {
    if (kIsWeb) {
      return ['http://localhost:5002'];
    } else if (Platform.isAndroid) {
      return [
        'http://10.0.2.2:5002',      // 에뮬레이터용 (우선순위)
        'http://127.0.0.1:5002',     // USB 디버깅 (ADB 포트 포워딩)
        'http://192.168.45.98:5002', // WiFi 연결 (노트북 실제 IP)
        'http://localhost:5002',     // USB 디버깅 대안
      ];
    } else {
      return ['http://localhost:5002'];
    }
  }

  // 여러 서버 주소 시도
  static Future<http.Response> _tryMultipleUrls(
    String endpoint,
    Map<String, String> headers,
  ) async {
    for (String baseUrl in serverUrls) {
      try {
        print('🌐 시도 중: $baseUrl$endpoint');
        final response = await http.get(
          Uri.parse('$baseUrl$endpoint'),
          headers: headers,
        ).timeout(const Duration(seconds: 10));
        
        if (response.statusCode == 200) {
          print('✅ 성공: $baseUrl$endpoint');
          return response;
        }
      } catch (e) {
        print('❌ 실패: $baseUrl$endpoint - $e');
        continue;
      }
    }
    
    throw Exception('모든 서버 주소에서 연결 실패');
  }

  /// 레벨별 커리큘럼 조회
  static Future<List<dynamic>?> getCurriculum({
    required String language,
    required int level,
  }) async {
    try {
      final authService = AuthService();
      final token = await authService.getToken();
      
      if (token == null) {
        print('❌ 토큰이 없습니다');
        return null;
      }

      final response = await _tryMultipleUrls(
        '/api/learning/$language/curriculum?level=$level',
        {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ 커리큘럼 조회 성공: ${data['curriculum']?.length ?? 0}개 레슨');
        return data['curriculum'];
      } else {
        final error = jsonDecode(response.body);
        print('❌ 커리큘럼 조회 실패: ${error['error']}');
        return null;
      }
    } catch (e) {
      print('❌ 커리큘럼 조회 오류: $e');
      return null;
    }
  }

  /// 전체 커리큘럼 조회 (모든 레벨)
  static Future<Map<int, List<dynamic>>?> getAllCurriculum({
    required String language,
  }) async {
    try {
      Map<int, List<dynamic>> allCurriculum = {};
      
      // 레벨 1-5까지 조회
      for (int level = 1; level <= 5; level++) {
        final curriculum = await getCurriculum(
          language: language,
          level: level,
        );
        
        if (curriculum != null) {
          allCurriculum[level] = curriculum;
        }
      }
      
      print('✅ 전체 커리큘럼 조회 완료: ${allCurriculum.keys.length}개 레벨');
      return allCurriculum;
    } catch (e) {
      print('❌ 전체 커리큘럼 조회 오류: $e');
      return null;
    }
  }
}
