import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../main.dart';

class AuthScreen extends StatefulWidget {
  final bool isLogin;  // true: 로그인, false: 회원가입
  
  const AuthScreen({super.key, this.isLogin = true});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // 로그인 폼 컨트롤러
  final _loginUsernameController = TextEditingController();
  final _loginPasswordController = TextEditingController();

  // 회원가입 폼 컨트롤러
  final _registerNicknameController = TextEditingController();
  final _registerUsernameController = TextEditingController();
  final _registerPasswordController = TextEditingController();
  final _registerConfirmPasswordController = TextEditingController();

  // Focus nodes
  final _loginUsernameFocus = FocusNode();
  final _loginPasswordFocus = FocusNode();
  final _registerNicknameFocus = FocusNode();
  final _registerUsernameFocus = FocusNode();
  final _registerPasswordFocus = FocusNode();
  final _registerConfirmPasswordFocus = FocusNode();

  bool _obscureLoginPassword = true;
  bool _obscureRegisterPassword = true;
  bool _obscureConfirmPassword = true;

  // 아이디 중복 체크 상태
  bool _isCheckingUsername = false;
  bool? _isUsernameAvailable; // null: 체크 안함, true: 사용가능, false: 중복

  // 비밀번호 확인 상태
  bool _showPasswordMismatch = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2, 
      vsync: this,
      initialIndex: widget.isLogin ? 0 : 1,  // 로그인/회원가입 초기 탭 설정
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginUsernameController.dispose();
    _loginPasswordController.dispose();
    _registerNicknameController.dispose();
    _registerUsernameController.dispose();
    _registerPasswordController.dispose();
    _registerConfirmPasswordController.dispose();

    // Focus nodes dispose
    _loginUsernameFocus.dispose();
    _loginPasswordFocus.dispose();
    _registerNicknameFocus.dispose();
    _registerUsernameFocus.dispose();
    _registerPasswordFocus.dispose();
    _registerConfirmPasswordFocus.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF2D3748)),
          onPressed: () => Navigator.pop(context),
        ),
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFF6B73FF), Color(0xFF9F7AEA)],
          ).createShader(bounds),
          child: const Text(
            'SignTalk',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        centerTitle: true,
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                // 헤더
                _buildHeader(),

                const SizedBox(height: 32),

                // 탭 바
                _buildTabBar(),

                const SizedBox(height: 24),

                // 에러 메시지
                if (authProvider.errorMessage != null)
                  _buildErrorMessage(authProvider.errorMessage!),

                // 탭 뷰
                SizedBox(
                  height: 500,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildLoginForm(authProvider),
                      _buildRegisterForm(authProvider),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              colors: [Color(0xFF6B73FF), Color(0xFF9F7AEA)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Icon(Icons.sign_language, color: Colors.white, size: 40),
        ),
        const SizedBox(height: 16),
        const Text(
          '환영합니다! 👋',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D3748),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'SignTalk과 함께 한국 수어를 배워보세요',
          style: TextStyle(fontSize: 16, color: Color(0xFF718096)),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: const LinearGradient(
            colors: [Color(0xFF4299E1), Color(0xFF9F7AEA)],
          ),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: const Color(0xFF718096),
        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
        tabs: const [
          Tab(text: '로그인'),
          Tab(text: '회원가입'),
        ],
      ),
    );
  }

  Widget _buildErrorMessage(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade600, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: Colors.red.shade700, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm(AuthProvider authProvider) {
    return Column(
      children: [
        _buildTextField(
          controller: _loginUsernameController,
          label: '아이디',
          icon: Icons.person_outline,
          focusNode: _loginUsernameFocus,
          nextFocusNode: _loginPasswordFocus,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _loginPasswordController,
          label: '비밀번호',
          icon: Icons.lock_outline,
          focusNode: _loginPasswordFocus,
          obscureText: _obscureLoginPassword,
          suffixIcon: IconButton(
            icon: Icon(
              _obscureLoginPassword ? Icons.visibility : Icons.visibility_off,
            ),
            onPressed: () {
              setState(() {
                _obscureLoginPassword = !_obscureLoginPassword;
              });
            },
          ),
        ),
        const SizedBox(height: 32),
        _buildSubmitButton(
          text: '로그인',
          isLoading: authProvider.isLoading,
          onPressed: () => _handleLogin(authProvider),
        ),
      ],
    );
  }

  Widget _buildRegisterForm(AuthProvider authProvider) {
    return Column(
      children: [
        // 아이디 필드
        _buildUsernameFieldWithCheck(),
        const SizedBox(height: 16),
        // 닉네임 필드
        _buildTextField(
          controller: _registerNicknameController,
          label: '닉네임',
          icon: Icons.person_outline,
          focusNode: _registerNicknameFocus,
          nextFocusNode: _registerPasswordFocus,
          hintText: '한글, 영문, 숫자만 사용 가능',
          onChanged: (value) {
            if (value.isNotEmpty && !_validateNickname(value)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('닉네임에는 특수문자를 사용할 수 없습니다'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 2),
                ),
              );
            }
          },
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _registerPasswordController,
          label: '비밀번호',
          icon: Icons.lock_outline,
          focusNode: _registerPasswordFocus,
          nextFocusNode: _registerConfirmPasswordFocus,
          obscureText: _obscureRegisterPassword,
          onChanged: (value) {
            _checkPasswordMatch();
          },
          suffixIcon: IconButton(
            icon: Icon(
              _obscureRegisterPassword
                  ? Icons.visibility
                  : Icons.visibility_off,
            ),
            onPressed: () {
              setState(() {
                _obscureRegisterPassword = !_obscureRegisterPassword;
              });
            },
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(left: 12, top: 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '비밀번호 규칙: 5자 이상, 영문/숫자/특수문자 포함',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTextField(
              controller: _registerConfirmPasswordController,
              label: '비밀번호 확인',
              icon: Icons.lock_outline,
              focusNode: _registerConfirmPasswordFocus,
              obscureText: _obscureConfirmPassword,
              onChanged: (value) {
                _checkPasswordMatch();
              },
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword
                      ? Icons.visibility
                      : Icons.visibility_off,
                ),
                onPressed: () {
                  setState(() {
                    _obscureConfirmPassword = !_obscureConfirmPassword;
                  });
                },
              ),
            ),
            if (_showPasswordMismatch) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 16),
                  const SizedBox(width: 4),
                  const Text(
                    '비밀번호를 다시 입력해주세요',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ],
              ),
            ],
          ],
        ),
        const SizedBox(height: 32),
        _buildSubmitButton(
          text: '회원가입',
          isLoading: authProvider.isLoading,
          onPressed: () => _handleRegister(authProvider),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    FocusNode? focusNode,
    FocusNode? nextFocusNode,
    Function(String)? onChanged,
    String? hintText,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscureText,
      keyboardType: keyboardType ?? TextInputType.text,
      textInputAction: nextFocusNode != null
          ? TextInputAction.next
          : TextInputAction.done,
      onChanged: onChanged,
      onSubmitted: (_) {
        if (nextFocusNode != null) {
          FocusScope.of(context).requestFocus(nextFocusNode);
        }
      },
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: Icon(icon, color: const Color(0xFF6B73FF)),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF6B73FF), width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
      ),
    );
  }

  String _getHintText(String label) {
    switch (label) {
      case '아이디':
        return 'user123 (5-20자, 소문자/숫자)';
      case '비밀번호':
      case '비밀번호 확인':
        return '5자 이상 입력';
      default:
        return '';
    }
  }

  // 아이디 중복 체크가 포함된 사용자명 필드
  Widget _buildUsernameFieldWithCheck() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                controller: _registerUsernameController,
                label: '아이디',
                icon: Icons.person_outline,
                focusNode: _registerUsernameFocus,
                nextFocusNode: _registerNicknameFocus,
                onChanged: (value) {
                  // 아이디가 변경되면 중복 체크 상태 초기화
                  setState(() {
                    _isUsernameAvailable = null;
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _isCheckingUsername
                  ? null
                  : _checkUsernameAvailability,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9F7AEA),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isCheckingUsername
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('중복확인', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        if (_isUsernameAvailable != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                _isUsernameAvailable! ? Icons.check_circle : Icons.error,
                color: _isUsernameAvailable! ? Colors.green : Colors.red,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                _isUsernameAvailable! ? '사용 가능한 아이디입니다' : '이미 사용 중인 아이디입니다',
                style: TextStyle(
                  color: _isUsernameAvailable! ? Colors.green : Colors.red,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // 비밀번호 일치 확인 메서드
  void _checkPasswordMatch() {
    final password = _registerPasswordController.text;
    final confirmPassword = _registerConfirmPasswordController.text;

    setState(() {
      // 비밀번호 확인 필드에 내용이 있고, 비밀번호와 다를 때만 에러 표시
      _showPasswordMismatch =
          confirmPassword.isNotEmpty && password != confirmPassword;
    });
  }

  // 닉네임 특수문자 검증 메서드
  bool _validateNickname(String nickname) {
    // 한글, 영문, 숫자, 공백만 허용 (유니코드 범위 사용)
    final RegExp validPattern = RegExp(
      r'^[\u1100-\u11FF\u3130-\u318F\uAC00-\uD7AFa-zA-Z0-9\s]+$',
    );
    return validPattern.hasMatch(nickname);
  }

  // 아이디 중복 체크 메서드
  Future<void> _checkUsernameAvailability() async {
    final username = _registerUsernameController.text.trim();

    if (username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('아이디를 입력해주세요'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (username.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('아이디는 5자 이상이어야 합니다'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (username.length > 20) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('아이디는 20자 이하여야 합니다'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isCheckingUsername = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final isAvailable = await authProvider.checkUsernameAvailability(
        username,
      );

      setState(() {
        _isUsernameAvailable = isAvailable;
        _isCheckingUsername = false;
      });
    } catch (e) {
      setState(() {
        _isCheckingUsername = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('중복 확인 중 오류가 발생했습니다'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildSubmitButton({
    required String text,
    required bool isLoading,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6B73FF), Color(0xFF9F7AEA)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            alignment: Alignment.center,
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    text,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  void _handleLogin(AuthProvider authProvider) async {
    // 간단한 유효성 검사
    if (_loginUsernameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('아이디를 입력해주세요'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_loginPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('비밀번호를 입력해주세요'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    authProvider.clearError();
    final success = await authProvider.login(
      _loginUsernameController.text.trim(),
      _loginPasswordController.text,
    );

    if (success && mounted) {
      // 로그인 성공 시 홈 화면으로 이동
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const SignTalkHomePage(),
        ),
        (route) => false,  // 모든 이전 화면 제거
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('로그인되었습니다! 🎉'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _handleRegister(AuthProvider authProvider) async {
    // 빈 필드 체크
    if (_registerNicknameController.text.trim().isEmpty ||
        _registerUsernameController.text.trim().isEmpty ||
        _registerPasswordController.text.isEmpty ||
        _registerConfirmPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('모든 필드를 입력해주세요'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 닉네임 특수문자 검증
    if (!_validateNickname(_registerNicknameController.text.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('닉네임에는 특수문자를 사용할 수 없습니다'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_registerUsernameController.text.trim().length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('아이디는 5자 이상이어야 합니다'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    // 아이디 중복 체크 확인
    if (_isUsernameAvailable != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('아이디 중복 확인을 해주세요'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_registerPasswordController.text.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('비밀번호는 5자 이상이어야 합니다'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_registerPasswordController.text !=
        _registerConfirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('비밀번호가 일치하지 않습니다'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    authProvider.clearError();
    final success = await authProvider.register(
      _registerUsernameController.text.trim(),
      'dummy@email.com', // 임시 이메일 (백엔드 호환성을 위해)
      _registerPasswordController.text,
      nickname: _registerNicknameController.text.trim(),
    );

    if (success && mounted) {
      // 회원가입 성공 시 홈 화면으로 이동
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const SignTalkHomePage(),
        ),
        (route) => false,  // 모든 이전 화면 제거
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('회원가입이 완료되었습니다! 🎉'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}
