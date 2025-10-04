import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

class AuthService {
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
    Map<String, String> headers,
    String body,
  ) async {
    for (String baseUrl in serverUrls) {
      try {
        final response = await http
            .post(Uri.parse('$baseUrl$endpoint'), headers: headers, body: body)
            .timeout(const Duration(seconds: 5));
        return response;
      } catch (e) {
        print('Failed to connect to $baseUrl: $e');
        continue;
      }
    }
    throw Exception('모든 서버 주소 연결 실패');
  }

  // 회원가입
  Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    String? nickname,
  }) async {
    try {
      final response = await _tryMultipleUrls(
        '/api/auth/register',
        {'Content-Type': 'application/json'},
        jsonEncode({
          'username': username,
          'email': '${username}_${DateTime.now().millisecondsSinceEpoch}@signtalk.local', // 고유한 더미 이메일
          'password': password,
          if (nickname != null) 'nickname': nickname,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        // 성공적으로 회원가입된 경우 토큰 저장
        await _saveToken(data['access_token']);
        return {
          'success': true,
          'message': data['message'],
          'user': User.fromJson(data['user']),
          'token': data['access_token'],
        };
      } else {
        return {'success': false, 'message': data['error'] ?? '회원가입에 실패했습니다.'};
      }
    } catch (e) {
      return {'success': false, 'message': '네트워크 오류가 발생했습니다: $e'};
    }
  }

  // 로그인
  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await _tryMultipleUrls('/api/auth/login', {
        'Content-Type': 'application/json',
      }, jsonEncode({'username': username, 'password': password}));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // 성공적으로 로그인된 경우 토큰 저장
        await _saveToken(data['access_token']);
        return {
          'success': true,
          'message': data['message'],
          'user': User.fromJson(data['user']),
          'token': data['access_token'],
        };
      } else {
        return {'success': false, 'message': data['error'] ?? '로그인에 실패했습니다.'};
      }
    } catch (e) {
      return {'success': false, 'message': '네트워크 오류가 발생했습니다: $e'};
    }
  }

  // 프로필 조회
  Future<Map<String, dynamic>> getProfile() async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': '로그인이 필요합니다.'};
      }

      // 첫 번째 서버 주소 사용 (GET 요청)
      final baseUrl = serverUrls.first;
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/auth/profile'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'user': User.fromJson(data['user']),
          'progress': data['progress'],
        };
      } else {
        return {
          'success': false,
          'message': data['error'] ?? '프로필 조회에 실패했습니다.',
        };
      }
    } catch (e) {
      return {'success': false, 'message': '네트워크 오류가 발생했습니다: $e'};
    }
  }

  // 로그아웃
  Future<void> logout() async {
    await _removeToken();
  }

  // 토큰 저장
  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  // 토큰 조회
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  // 토큰 삭제
  Future<void> _removeToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  // 아이디 중복 체크
  Future<Map<String, dynamic>> checkUsernameAvailability(String username) async {
    try {
      final response = await _tryMultipleUrls('/api/auth/check-username', {
        'Content-Type': 'application/json',
      }, jsonEncode({'username': username}));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'available': data['available'] ?? false,
          'message': data['message'],
        };
      } else {
        return {
          'success': false,
          'available': false,
          'message': data['error'] ?? '아이디 중복 확인에 실패했습니다.',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'available': false,
        'message': '네트워크 오류가 발생했습니다: $e',
      };
    }
  }

  // 로그인 상태 확인
  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null;
  }
}
