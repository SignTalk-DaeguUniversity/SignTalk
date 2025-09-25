import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'providers/auth_provider.dart';
import 'screens/auth_screen.dart';

void main() {
  runApp(const SignTalkApp());
}

class SignTalkApp extends StatelessWidget {
  const SignTalkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AuthProvider()..initialize(),
      child: MaterialApp(
        title: 'SignTalk',
        theme: ThemeData(primarySwatch: Colors.blue, fontFamily: 'NotoSans'),
        home: const SignTalkHomePage(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class SignTalkHomePage extends StatefulWidget {
  const SignTalkHomePage({super.key});

  @override
  State<SignTalkHomePage> createState() => _SignTalkHomePageState();
}

class _SignTalkHomePageState extends State<SignTalkHomePage> {
  bool isLearningMode = true;
  bool isQuizStarted = false;
  bool showQuizResult = false;
  String selectedQuizType = '';
  int currentQuestionIndex = 0;
  int totalQuestions = 24;
  int timeRemaining = 25;
  Timer? _timer;
  int correctAnswers = 0;
  int totalTimeSpent = 0;

  // 난이도별 문제 데이터
  final Map<String, List<Map<String, String>>> quizData = {
    '날말퀴즈': [
      // 자음 14개
      {'type': '자음', 'question': 'ㄱ', 'description': '위 자음을 수어로 표현해주세요'},
      {'type': '자음', 'question': 'ㄴ', 'description': '위 자음을 수어로 표현해주세요'},
      {'type': '자음', 'question': 'ㄷ', 'description': '위 자음을 수어로 표현해주세요'},
      {'type': '자음', 'question': 'ㄹ', 'description': '위 자음을 수어로 표현해주세요'},
      {'type': '자음', 'question': 'ㅁ', 'description': '위 자음을 수어로 표현해주세요'},
      {'type': '자음', 'question': 'ㅂ', 'description': '위 자음을 수어로 표현해주세요'},
      {'type': '자음', 'question': 'ㅅ', 'description': '위 자음을 수어로 표현해주세요'},
      {'type': '자음', 'question': 'ㅇ', 'description': '위 자음을 수어로 표현해주세요'},
      {'type': '자음', 'question': 'ㅈ', 'description': '위 자음을 수어로 표현해주세요'},
      {'type': '자음', 'question': 'ㅊ', 'description': '위 자음을 수어로 표현해주세요'},
      {'type': '자음', 'question': 'ㅋ', 'description': '위 자음을 수어로 표현해주세요'},
      {'type': '자음', 'question': 'ㅌ', 'description': '위 자음을 수어로 표현해주세요'},
      {'type': '자음', 'question': 'ㅍ', 'description': '위 자음을 수어로 표현해주세요'},
      {'type': '자음', 'question': 'ㅎ', 'description': '위 자음을 수어로 표현해주세요'},
      // 모음 10개
      {'type': '모음', 'question': 'ㅏ', 'description': '위 모음을 수어로 표현해주세요'},
      {'type': '모음', 'question': 'ㅑ', 'description': '위 모음을 수어로 표현해주세요'},
      {'type': '모음', 'question': 'ㅓ', 'description': '위 모음을 수어로 표현해주세요'},
      {'type': '모음', 'question': 'ㅕ', 'description': '위 모음을 수어로 표현해주세요'},
      {'type': '모음', 'question': 'ㅗ', 'description': '위 모음을 수어로 표현해주세요'},
      {'type': '모음', 'question': 'ㅛ', 'description': '위 모음을 수어로 표현해주세요'},
      {'type': '모음', 'question': 'ㅜ', 'description': '위 모음을 수어로 표현해주세요'},
      {'type': '모음', 'question': 'ㅠ', 'description': '위 모음을 수어로 표현해주세요'},
      {'type': '모음', 'question': 'ㅡ', 'description': '위 모음을 수어로 표현해주세요'},
      {'type': '모음', 'question': 'ㅣ', 'description': '위 모음을 수어로 표현해주세요'},
    ],
    '초급': [
      {'type': '받침 없는 글자', 'question': '아', 'description': '위 글자를 수어로 표현해주세요'},
      {'type': '받침 없는 글자', 'question': '오', 'description': '위 글자를 수어로 표현해주세요'},
      {'type': '받침 없는 글자', 'question': '우', 'description': '위 글자를 수어로 표현해주세요'},
      {'type': '받침 없는 글자', 'question': '이', 'description': '위 글자를 수어로 표현해주세요'},
      {'type': '받침 없는 글자', 'question': '어', 'description': '위 글자를 수어로 표현해주세요'},
    ],
    '중급': [
      {'type': '받침 있는 글자', 'question': '안', 'description': '위 글자를 수어로 표현해주세요'},
      {'type': '받침 있는 글자', 'question': '은', 'description': '위 글자를 수어로 표현해주세요'},
      {'type': '받침 있는 글자', 'question': '을', 'description': '위 글자를 수어로 표현해주세요'},
      {'type': '받침 있는 글자', 'question': '한', 'description': '위 글자를 수어로 표현해주세요'},
      {'type': '받침 있는 글자', 'question': '밥', 'description': '위 글자를 수어로 표현해주세요'},
    ],
    '고급': [
      {'type': '단어', 'question': '안녕', 'description': '위 단어를 수어로 표현해주세요'},
      {'type': '단어', 'question': '사랑', 'description': '위 단어를 수어로 표현해주세요'},
      {'type': '단어', 'question': '감사', 'description': '위 단어를 수어로 표현해주세요'},
      {'type': '단어', 'question': '미안', 'description': '위 단어를 수어로 표현해주세요'},
      {'type': '단어', 'question': '좋아', 'description': '위 단어를 수어로 표현해주세요'},
    ],
  };

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (timeRemaining > 0) {
        setState(() {
          timeRemaining--;
        });
      } else {
        _timer?.cancel();
        _nextQuestion();
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
  }

  void _nextQuestion() {
    if (currentQuestionIndex < totalQuestions - 1) {
      setState(() {
        currentQuestionIndex++;
        timeRemaining = 25;
      });
      _startTimer();
    } else {
      // 퀴즈 완료
      _stopTimer();
      setState(() {
        isQuizStarted = false;
        showQuizResult = true;
        totalTimeSpent = (totalQuestions * 25) - (timeRemaining); // 대략적인 시간 계산
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: Column(
        children: [
          // Header
          _buildHeader(),

          // Main content area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Mode tabs
                    _buildModeTabs(),

                    const SizedBox(height: 16),

                    // Learning/Quiz mode selector
                    _buildModeSelector(),

                    const SizedBox(height: 16),

                    // Content based on mode
                    if (showQuizResult) ...[
                      // Quiz result screen
                      _buildQuizResultScreen(),
                    ] else if (isQuizStarted) ...[
                      // Quiz screen
                      _buildQuizScreen(),
                    ] else if (isLearningMode) ...[
                      // Learning mode content
                      Container(
                        height: 200,
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(horizontal: 0),
                        child: _buildCameraArea(),
                      ),

                      const SizedBox(height: 16),

                      // Recognition result area
                      _buildRecognitionArea(),

                      const SizedBox(height: 16),

                      // Recognition history area
                      _buildRecognitionHistory(),

                      const SizedBox(height: 16),

                      // Sidebar area
                      _buildSidebar(),
                    ] else ...[
                      // Quiz mode content
                      _buildQuizModeContent(),
                    ],

                    const SizedBox(height: 24),

                    // Bottom description
                    _buildBottomDescription(),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Logo
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6B73FF), Color(0xFF9F7AEA)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(
                  Icons.sign_language,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFF6B73FF), Color(0xFF9F7AEA)],
                ).createShader(bounds),
                child: const Text(
                  'SignTalk',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),

          const Spacer(),

          // Login button
          _buildLoginButton(),
        ],
      ),
    );
  }

  Widget _buildLoginButton() {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        if (authProvider.isLoggedIn && authProvider.user != null) {
          // 로그인된 상태
          return PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                authProvider.logout();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('로그아웃되었습니다'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    const Icon(Icons.person, size: 18),
                    const SizedBox(width: 8),
                    Text(authProvider.user!.username),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 18),
                    SizedBox(width: 8),
                    Text('로그아웃'),
                  ],
                ),
              ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6B73FF), Color(0xFF9F7AEA)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person, size: 18, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(
                    authProvider.user!.username,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_drop_down, size: 18, color: Colors.white),
                ],
              ),
            ),
          );
        } else {
          // 로그인되지 않은 상태
          return ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AuthScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
              shadowColor: Colors.transparent,
              backgroundColor: Colors.transparent,
            ),
            child: Ink(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6B73FF), Color(0xFF9F7AEA)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Container(
                constraints: const BoxConstraints(minWidth: 100, minHeight: 40),
                alignment: Alignment.center,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.login, size: 18, color: Colors.white),
                    SizedBox(width: 6),
                    Text(
                      '로그인',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
      },
    );
  }

  Widget _buildModeTabs() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            '✨ 한국 수어 학습 플랫폼 👋',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D3748),
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            '✨ AI 기반 실시간 수어 인식으로 체계적인 한국 수어 학습을 경험해보세요 ✨',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF718096),
              height: 1.4,
            ),
          ),

          const SizedBox(height: 24),

          // Feature buttons
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              _buildFeatureButton('📖', '텍스트 지원', const Color(0xFF4299E1)),
              _buildFeatureButton('🎯', '모델링 최적화', const Color(0xFF9F7AEA)),
              _buildFeatureButton('💖', '자료 모음 & 퀴즈', const Color(0xFFED64A6)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureButton(String emoji, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: color.withOpacity(0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: color.withOpacity(0.9),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  isLearningMode = true;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  gradient: isLearningMode
                      ? const LinearGradient(
                          colors: [Color(0xFF4299E1), Color(0xFF9F7AEA)],
                        )
                      : null,
                  color: isLearningMode ? null : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.school,
                      color: isLearningMode
                          ? Colors.white
                          : const Color(0xFF718096),
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '학습 모드',
                      style: TextStyle(
                        color: isLearningMode
                            ? Colors.white
                            : const Color(0xFF718096),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  isLearningMode = false;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  gradient: !isLearningMode
                      ? const LinearGradient(
                          colors: [Color(0xFF4299E1), Color(0xFF9F7AEA)],
                        )
                      : null,
                  color: !isLearningMode ? null : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.quiz,
                      color: !isLearningMode
                          ? Colors.white
                          : const Color(0xFF718096),
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '퀴즈 모드',
                      style: TextStyle(
                        color: !isLearningMode
                            ? Colors.white
                            : const Color(0xFF718096),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraArea() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.camera_alt_outlined,
            size: 48,
            color: Color(0xFF9CA3AF),
          ),
          const SizedBox(height: 12),
          const Text(
            '카메라가 꺼져있습니다',
            style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
            label: const Text(
              '카메라 켜기',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1F2937),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecognitionArea() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '현재 인식 결과',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7FAFC),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '0개',
                  style: TextStyle(fontSize: 12, color: Color(0xFF718096)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAFA),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.timeline, size: 32, color: Color(0xFFCBD5E0)),
                SizedBox(height: 8),
                Text(
                  '수어를 인식 중입니다...',
                  style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                ),
                Text(
                  '카메라 앞에서 수어를 보여주세요',
                  style: TextStyle(color: Color(0xFFCBD5E0), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecognitionHistory() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '인식 기록',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7FAFC),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '0개',
                  style: TextStyle(fontSize: 12, color: Color(0xFF718096)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAFA),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Center(
              child: Text(
                '아직 인식된 수어가 없습니다',
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizResultScreen() {
    double accuracy = totalQuestions > 0
        ? (correctAnswers / totalQuestions * 100)
        : 0;
    int minutes = totalTimeSpent ~/ 60;
    int seconds = totalTimeSpent % 60;

    return Column(
      children: [
        // Result header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Trophy icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(40),
                ),
                child: const Icon(
                  Icons.emoji_events,
                  size: 40,
                  color: Color(0xFF2196F3),
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                '퀴즈 완료!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748),
                ),
              ),

              const SizedBox(height: 8),

              Text(
                '$selectedQuizType 퀴즈를 완료했습니다',
                style: const TextStyle(fontSize: 16, color: Color(0xFF718096)),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Stats cards
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                '$correctAnswers',
                '정답',
                const Color(0xFF10B981),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                '${accuracy.toInt()}%',
                '정확도',
                const Color(0xFF3B82F6),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                '${minutes}분${seconds}초',
                '평균 시간',
                const Color(0xFF8B5CF6),
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Detailed results
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '상세 결과',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748),
                ),
              ),
              const SizedBox(height: 16),
              _buildResultItem('총 문제 수', '$totalQuestions개'),
              _buildResultItem('정답 수', '$correctAnswers개'),
              _buildResultItem('오답 수', '${totalQuestions - correctAnswers}개'),
              _buildResultItem('정확도', '${accuracy.toInt()}%'),
              _buildResultItem('소요 시간', '${minutes}분 ${seconds}초'),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Action buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    showQuizResult = false;
                    selectedQuizType = '';
                    currentQuestionIndex = 0;
                    correctAnswers = 0;
                    totalTimeSpent = 0;
                  });
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.refresh, size: 18, color: Color(0xFF718096)),
                    SizedBox(width: 6),
                    Text(
                      '다시 하기',
                      style: TextStyle(fontSize: 14, color: Color(0xFF718096)),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    showQuizResult = false;
                    selectedQuizType = '';
                    currentQuestionIndex = 0;
                    correctAnswers = 0;
                    totalTimeSpent = 0;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1F2937),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.play_arrow, size: 18, color: Colors.white),
                    SizedBox(width: 6),
                    Text(
                      '새 퀴즈',
                      style: TextStyle(fontSize: 14, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: color.withOpacity(0.8)),
          ),
        ],
      ),
    );
  }

  Widget _buildResultItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14, color: Color(0xFF718096)),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D3748),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizScreen() {
    return Column(
      children: [
        // Quiz header with progress and timer
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Progress and timer row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '문제 ${currentQuestionIndex + 1} / $totalQuestions',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2D3748),
                    ),
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 18,
                        color: timeRemaining <= 5
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF718096),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${timeRemaining}초',
                        style: TextStyle(
                          fontSize: 14,
                          color: timeRemaining <= 5
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF718096),
                          fontWeight: timeRemaining <= 5
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Progress bar
              Container(
                width: double.infinity,
                height: 8,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: (currentQuestionIndex + 1) / totalQuestions,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF2D3748),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Question card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                quizData[selectedQuizType]![currentQuestionIndex]['type']!,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF718096),
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 16),

              Text(
                quizData[selectedQuizType]![currentQuestionIndex]['question']!,
                style: const TextStyle(
                  fontSize: 72,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748),
                ),
              ),

              const SizedBox(height: 16),

              Text(
                quizData[selectedQuizType]![currentQuestionIndex]['description']!,
                style: const TextStyle(fontSize: 16, color: Color(0xFF4A5568)),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Camera area
        Container(
          width: double.infinity,
          height: 200,
          decoration: BoxDecoration(
            color: const Color(0xFFF0F0F0),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.camera_alt_outlined,
                size: 48,
                color: Color(0xFF9CA3AF),
              ),
              const SizedBox(height: 12),
              const Text(
                '카메라가 꺼져있습니다',
                style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: 18,
                ),
                label: const Text(
                  '카메라 켜기',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1F2937),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Bottom buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  _stopTimer();
                  setState(() {
                    isQuizStarted = false;
                    showQuizResult = true;
                    totalTimeSpent =
                        ((currentQuestionIndex + 1) * 25) - timeRemaining;
                  });
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                child: const Text(
                  '퀴즈 중단',
                  style: TextStyle(fontSize: 14, color: Color(0xFF718096)),
                ),
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1F2937),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '카메라 켜기',
                  style: TextStyle(fontSize: 14, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuizModeContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Quiz mode header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF9F7AEA), Color(0xFFED64A6)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.quiz,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    '퀴즈 모드 선택',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3748),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                '원하는 난이도를 선택하여 수어 퀴즈에 도전해보세요',
                style: TextStyle(fontSize: 14, color: Color(0xFF718096)),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Learning mode selection
        const Text(
          '학습 모드 선택',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D3748),
          ),
        ),

        const SizedBox(height: 12),

        // Quiz level cards
        _buildQuizLevelCard(
          '날말퀴즈',
          '24개 문제',
          '한국어 자음과 모음 랜덤퀴즈',
          const Color(0xFF6366F1),
          Icons.text_fields,
          () {
            setState(() {
              selectedQuizType = '날말퀴즈';
              totalQuestions = 24;
            });
          },
        ),

        const SizedBox(height: 12),

        _buildQuizLevelCard(
          '초급',
          '5개 문제',
          '받침 없는 글자들 (아, 오, 우, 이, 어)',
          const Color(0xFF10B981),
          Icons.sentiment_satisfied,
          () {
            setState(() {
              selectedQuizType = '초급';
              totalQuestions = 5;
            });
          },
        ),

        const SizedBox(height: 12),

        _buildQuizLevelCard(
          '중급',
          '5개 문제',
          '받침 있는 글자들 (안, 은, 을, 한, 밥)',
          const Color(0xFFF59E0B),
          Icons.sentiment_neutral,
          () {
            setState(() {
              selectedQuizType = '중급';
              totalQuestions = 5;
            });
          },
        ),

        const SizedBox(height: 12),

        _buildQuizLevelCard(
          '고급',
          '5개 문제',
          '완전한 단어들 (안녕, 사랑, 감사, 미안, 좋아)',
          const Color(0xFFEF4444),
          Icons.sentiment_very_dissatisfied,
          () {
            setState(() {
              selectedQuizType = '고급';
              totalQuestions = 5;
            });
          },
        ),

        const SizedBox(height: 24),

        // Quiz rules
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '퀴즈 규칙',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748),
                ),
              ),
              const SizedBox(height: 12),
              _buildRuleItem('• 각 문제마다 30초의 시간이 주어집니다'),
              _buildRuleItem('• 카메라 앞에서 올바른 수어를 표현하세요'),
              _buildRuleItem('• 정확도와 속도에 따라 점수가 결정됩니다'),
              _buildRuleItem('• 틀려도 괜찮습니다. 반복 학습이 중요해요!'),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Start quiz button
        Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF9F7AEA), Color(0xFFED64A6)],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A9F7AEA),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: selectedQuizType.isNotEmpty
                ? () {
                    setState(() {
                      isQuizStarted = true;
                      currentQuestionIndex = 0;
                      timeRemaining = 25;
                    });
                    _startTimer();
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.play_arrow, color: Colors.white, size: 24),
                SizedBox(width: 8),
                Text(
                  '퀴즈 시작',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuizLevelCard(
    String title,
    String count,
    String description,
    Color color,
    IconData icon,
    VoidCallback onTap,
  ) {
    bool isSelected = selectedQuizType == title;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? color.withOpacity(0.1)
                  : const Color(0x05000000),
              blurRadius: isSelected ? 8 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D3748),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        count,
                        style: TextStyle(
                          fontSize: 12,
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF718096),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRuleItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          color: Color(0xFF718096),
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with stats
          Row(
            children: [
              const Text(
                '제어판',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748),
                ),
              ),
              const Spacer(),
              const Text(
                '중지됨',
                style: TextStyle(fontSize: 12, color: Color(0xFF718096)),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Stats section
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    const Text(
                      '0',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3748),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '인식된 단어',
                      style: TextStyle(fontSize: 12, color: Color(0xFF718096)),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 40, color: const Color(0xFFE2E8F0)),
              Expanded(
                child: Column(
                  children: [
                    const Text(
                      'OFF',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3748),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '카메라 상태',
                      style: TextStyle(fontSize: 12, color: Color(0xFF718096)),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: _buildActionButton(Icons.delete_outline, '기록 지우기'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(Icons.download_outlined, '결과 다운로드'),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Usage guide
          Row(
            children: [
              const Icon(
                Icons.info_outline,
                size: 16,
                color: Color(0xFF4299E1),
              ),
              const SizedBox(width: 8),
              const Text(
                '사용 가이드',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4299E1),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Guide items
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildGuideItem('• 카메라를 켜고 수어를 보여주세요'),
              _buildGuideItem('• 밝은 곳에서 사용하면 더 정확합니다'),
              _buildGuideItem('• 손동작을 천천히 명확하게 해주세요'),
              _buildGuideItem('• 현재 15개의 기본 수어를 인식합니다'),
            ],
          ),

          const SizedBox(height: 20),

          // Supported signs
          Row(
            children: [
              const Icon(
                Icons.settings_outlined,
                size: 16,
                color: Color(0xFF4299E1),
              ),
              const SizedBox(width: 8),
              const Text(
                '지원되는 수어',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4299E1),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Sign tags
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              '안녕하세요',
              '감사합니다',
              '사랑',
              '물',
              '밥',
              '집',
              '학교',
              '친구',
              '엄마',
              '아빠',
              '예',
              '아니오',
              '도움',
              '미안',
              '좋아',
            ].map((sign) => _buildSignTag(sign)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF718096)),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(fontSize: 12, color: Color(0xFF718096)),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF718096),
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildSignTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBAE6FD)),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11, color: Color(0xFF0369A1)),
      ),
    );
  }

  Widget _buildBottomDescription() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🎯', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            const Text('✨', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            const Text('💡', style: TextStyle(fontSize: 20)),
          ],
        ),
        const SizedBox(height: 12),
        RichText(
          textAlign: TextAlign.center,
          text: const TextSpan(
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF4A5568),
              height: 1.5,
            ),
            children: [
              TextSpan(
                text: 'SignTalk',
                style: TextStyle(
                  color: Color(0xFF4299E1),
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextSpan(
                text:
                    '은 세계적인 한국 수어 학습을 위한 교육 플랫폼입니다. AI를 이용한 기반 인식 시스템으로 실전 같은 학습 경험을 제공합니다. 👋',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          '자유로운 학습으로 가족을 다지고, 퀴즈로 실력을 검증하며, 자유 연습으로 완성해보세요! 💪',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Color(0xFF718096), height: 1.5),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🎨', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            const Text('🔥', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            const Text('🎈', style: TextStyle(fontSize: 16)),
          ],
        ),
      ],
    );
  }
}
