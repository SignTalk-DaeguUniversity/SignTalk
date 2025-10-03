import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  
  User? _user;
  bool _isLoading = false;
  bool _isLoggedIn = false;
  String? _errorMessage;

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _isLoggedIn;
  String? get errorMessage => _errorMessage;

  // 초기화 - 앱 시작시 로그인 상태 확인
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      final isLoggedIn = await _authService.isLoggedIn();
      if (isLoggedIn) {
        final result = await _authService.getProfile();
        if (result['success']) {
          _user = result['user'];
          _isLoggedIn = true;
        }
      }
    } catch (e) {
      _errorMessage = '초기화 중 오류가 발생했습니다: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  // 로그인
  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authService.login(
        username: username,
        password: password,
      );

      if (result['success']) {
        _user = result['user'];
        _isLoggedIn = true;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = result['message'];
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = '로그인 중 오류가 발생했습니다: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // 회원가입
  Future<bool> register(String username, String email, String password, {String? nickname}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authService.register(
        username: username,
        email: email,
        password: password,
        nickname: nickname,
      );

      if (result['success']) {
        _user = result['user'];
        _isLoggedIn = true;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = result['message'];
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = '회원가입 중 오류가 발생했습니다: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  // 로그아웃
  Future<void> logout() async {
    await _authService.logout();
    _user = null;
    _isLoggedIn = false;
    notifyListeners();
  }

  // 사용자 정보 업데이트 (닉네임 수정용)
  void updateUser(User updatedUser) {
    _user = updatedUser;
    notifyListeners();
  }

  // 아이디 중복 체크
  Future<bool> checkUsernameAvailability(String username) async {
    try {
      final result = await _authService.checkUsernameAvailability(username);
      return result['available'] ?? false;
    } catch (e) {
      throw Exception('아이디 중복 확인 실패: $e');
    }
  }

  // 에러 메시지 초기화
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
