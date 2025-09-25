import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // 로그인 폼 컨트롤러
  final _loginUsernameController = TextEditingController();
  final _loginPasswordController = TextEditingController();

  // 회원가입 폼 컨트롤러
  final _registerUsernameController = TextEditingController();
  final _registerEmailController = TextEditingController();
  final _registerPasswordController = TextEditingController();
  final _registerConfirmPasswordController = TextEditingController();

  // Focus nodes
  final _loginUsernameFocus = FocusNode();
  final _loginPasswordFocus = FocusNode();
  final _registerUsernameFocus = FocusNode();
  final _registerEmailFocus = FocusNode();
  final _registerPasswordFocus = FocusNode();
  final _registerConfirmPasswordFocus = FocusNode();

  bool _obscureLoginPassword = true;
  bool _obscureRegisterPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginUsernameController.dispose();
    _loginPasswordController.dispose();
    _registerUsernameController.dispose();
    _registerEmailController.dispose();
    _registerPasswordController.dispose();
    _registerConfirmPasswordController.dispose();
    
    // Focus nodes dispose
    _loginUsernameFocus.dispose();
    _loginPasswordFocus.dispose();
    _registerUsernameFocus.dispose();
    _registerEmailFocus.dispose();
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
          child: const Icon(
            Icons.sign_language,
            color: Colors.white,
            size: 40,
          ),
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
          style: TextStyle(
            fontSize: 16,
            color: Color(0xFF718096),
          ),
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
          label: '사용자명',
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
            icon: Icon(_obscureLoginPassword ? Icons.visibility : Icons.visibility_off),
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
        _buildTextField(
          controller: _registerUsernameController,
          label: '사용자명',
          icon: Icons.person_outline,
          focusNode: _registerUsernameFocus,
          nextFocusNode: _registerEmailFocus,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _registerEmailController,
          label: '이메일',
          icon: Icons.email_outlined,
          focusNode: _registerEmailFocus,
          nextFocusNode: _registerPasswordFocus,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _registerPasswordController,
          label: '비밀번호',
          icon: Icons.lock_outline,
          focusNode: _registerPasswordFocus,
          nextFocusNode: _registerConfirmPasswordFocus,
          obscureText: _obscureRegisterPassword,
          suffixIcon: IconButton(
            icon: Icon(_obscureRegisterPassword ? Icons.visibility : Icons.visibility_off),
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
              '비밀번호 규칙: 6자 이상, 숫자 포함, 특수문자 포함',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _registerConfirmPasswordController,
          label: '비밀번호 확인',
          icon: Icons.lock_outline,
          focusNode: _registerConfirmPasswordFocus,
          obscureText: _obscureConfirmPassword,
          suffixIcon: IconButton(
            icon: Icon(_obscureConfirmPassword ? Icons.visibility : Icons.visibility_off),
            onPressed: () {
              setState(() {
                _obscureConfirmPassword = !_obscureConfirmPassword;
              });
            },
          ),
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
    TextInputType? keyboardType,
    FocusNode? focusNode,
    FocusNode? nextFocusNode,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscureText,
      keyboardType: keyboardType ?? TextInputType.text,
      textInputAction: nextFocusNode != null ? TextInputAction.next : TextInputAction.done,
      // 한글 입력을 위한 설정
      inputFormatters: keyboardType == TextInputType.emailAddress 
          ? [FilteringTextInputFormatter.deny(RegExp(r'[ㄱ-ㅎ가-힣]'))] // 이메일은 한글 제외
          : [], // 다른 필드는 한글 허용
      onSubmitted: (_) {
        if (nextFocusNode != null) {
          FocusScope.of(context).requestFocus(nextFocusNode);
        }
      },
      decoration: InputDecoration(
        labelText: label,
        hintText: _getHintText(label),
        prefixIcon: Icon(icon, color: const Color(0xFF9F7AEA)),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF9F7AEA), width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  String _getHintText(String label) {
    switch (label) {
      case '사용자명':
        return '홍길동 또는 user123';
      case '이메일':
        return 'example@email.com';
      case '비밀번호':
      case '비밀번호 확인':
        return '6자 이상 입력';
      default:
        return '';
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
        const SnackBar(content: Text('사용자명을 입력해주세요'), backgroundColor: Colors.red),
      );
      return;
    }
    if (_loginPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('비밀번호를 입력해주세요'), backgroundColor: Colors.red),
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
      Navigator.of(context).popUntil((route) => route.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('로그인되었습니다! 🎉'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _handleRegister(AuthProvider authProvider) async {
    // 간단한 유효성 검사
    if (_registerUsernameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사용자명을 입력해주세요'), backgroundColor: Colors.red),
      );
      return;
    }
    if (_registerUsernameController.text.trim().length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사용자명은 3자 이상이어야 합니다'), backgroundColor: Colors.red),
      );
      return;
    }
    if (_registerEmailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이메일을 입력해주세요'), backgroundColor: Colors.red),
      );
      return;
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(_registerEmailController.text.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('올바른 이메일 형식을 입력해주세요'), backgroundColor: Colors.red),
      );
      return;
    }
    if (_registerPasswordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('비밀번호는 6자 이상이어야 합니다'), backgroundColor: Colors.red),
      );
      return;
    }
    if (_registerPasswordController.text != _registerConfirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('비밀번호가 일치하지 않습니다'), backgroundColor: Colors.red),
      );
      return;
    }

    authProvider.clearError();
    final success = await authProvider.register(
      _registerUsernameController.text.trim(),
      _registerEmailController.text.trim(),
      _registerPasswordController.text,
    );

    if (success && mounted) {
      // 회원가입 성공 시 홈 화면으로 이동
      Navigator.of(context).popUntil((route) => route.isFirst);
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
