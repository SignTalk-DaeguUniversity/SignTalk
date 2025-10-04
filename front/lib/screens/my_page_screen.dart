import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../services/progress_service.dart';
import '../services/auth_service.dart';
import '../services/quiz_service.dart';
// import '../main.dart'; // 충돌 방지를 위해 제거

class MyPageScreen extends StatefulWidget {
  const MyPageScreen({super.key});

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  Map<String, dynamic>? userProgress;
  bool isLoadingProgress = false;
  bool isEditingNickname = false;
  final TextEditingController _nicknameController = TextEditingController();
  bool showQuizStats = false; // 퀴즈 통계 표시 여부
  Map<String, dynamic>? quizStatistics; // 퀴즈 통계 데이터
  bool isLoadingQuizStats = false;

  @override
  void initState() {
    super.initState();
    _loadUserProgress();
    _loadQuizStatistics();
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProgress() async {
    setState(() {
      isLoadingProgress = true;
    });

    try {
      final progress = await ProgressService.getProgress('ksl');
      if (progress['success']) {
        setState(() {
          userProgress = progress['progress'];
        });
      }
    } catch (e) {
      print('진도 불러오기 실패: $e');
    } finally {
      setState(() {
        isLoadingProgress = false;
      });
    }
  }

  // 퀴즈 통계 불러오기 (백엔드 API 연동)
  Future<void> _loadQuizStatistics() async {
    setState(() {
      isLoadingQuizStats = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (!authProvider.isLoggedIn) {
        print('❌ 로그인되지 않음 - 퀴즈 통계 로드 불가');
        return;
      }

      final authService = AuthService();
      final token = await authService.getToken();
      
      if (token == null) {
        print('❌ 토큰 없음 - 퀴즈 통계 로드 불가');
        return;
      }

      print('📊 백엔드에서 퀴즈 통계 로드 중...');
      
      // 백엔드 퀴즈 통계 API 호출
      final result = await QuizService.getQuizStatistics('ksl');

      if (result['success']) {
        final statistics = result['statistics'] ?? {};
        final levelBreakdown = result['level_breakdown'] ?? [];
        
        print('✅ 퀴즈 통계 로드 성공');
        print('   - 총 퀴즈: ${statistics['total_quizzes']}');
        print('   - 정답: ${statistics['correct_quizzes']}');
        print('   - 정확도: ${statistics['accuracy']}%');
        
        // 레벨별 통계를 모드별로 변환
        final modeStats = {
          '낱말퀴즈': {'attempts': 0, 'correct': 0, 'total_questions': 0, 'accuracy': 0.0, 'has_data': false},
          '초급': {'attempts': 0, 'correct': 0, 'total_questions': 0, 'accuracy': 0.0, 'has_data': false},
          '중급': {'attempts': 0, 'correct': 0, 'total_questions': 0, 'accuracy': 0.0, 'has_data': false},
          '고급': {'attempts': 0, 'correct': 0, 'total_questions': 0, 'accuracy': 0.0, 'has_data': false},
        };
        
        // 레벨 매핑 (백엔드 레벨 -> 모드명)
        final levelToMode = {
          1: '낱말퀴즈',
          2: '초급',
          3: '중급',
          4: '고급',
        };
        
        for (var levelData in levelBreakdown) {
          final level = levelData['level'];
          final mode = levelToMode[level];
          
          if (mode != null) {
            modeStats[mode] = {
              'attempts': levelData['session_count'] ?? 0,  // 세션 횟수로 변경
              'correct': levelData['correct_answers'] ?? 0,
              'total_questions': levelData['total_questions'] ?? 0,
              'accuracy': levelData['accuracy'] ?? 0.0,
              'has_data': (levelData['session_count'] ?? 0) > 0,
            };
            
            print('   - $mode: 시도 ${levelData['session_count']}회, 정답 ${levelData['correct_answers']}/${levelData['total_questions']} (${levelData['accuracy']}%)');
          }
        }
        
        setState(() {
          quizStatistics = {
            'total_sessions': statistics['total_quizzes'] ?? 0,
            'total_quizzes': statistics['total_quizzes'] ?? 0,
            'correct_quizzes': statistics['correct_quizzes'] ?? 0,
            'average_accuracy': statistics['accuracy'] ?? 0.0,
            'mode_statistics': modeStats,
          };
        });
        
      } else {
        print('❌ 퀴즈 통계 API 호출 실패: ${result['error']}');
        
        // 실패 시 빈 데이터 설정
        setState(() {
          quizStatistics = {
            'total_sessions': 0,
            'mode_statistics': {
              '낱말퀴즈': {'attempts': 0, 'correct': 0, 'total_questions': 0, 'accuracy': 0.0, 'has_data': false},
              '초급': {'attempts': 0, 'correct': 0, 'total_questions': 0, 'accuracy': 0.0, 'has_data': false},
              '중급': {'attempts': 0, 'correct': 0, 'total_questions': 0, 'accuracy': 0.0, 'has_data': false},
              '고급': {'attempts': 0, 'correct': 0, 'total_questions': 0, 'accuracy': 0.0, 'has_data': false},
            }
          };
        });
      }
      
    } catch (e) {
      print('❌ 퀴즈 통계 로드 실패: $e');
      
      // 오류 시 빈 데이터 설정
      setState(() {
        quizStatistics = {
          'total_sessions': 0,
          'mode_statistics': {
            '낱말퀴즈': {'attempts': 0, 'correct': 0, 'total_questions': 0, 'accuracy': 0.0, 'has_data': false},
            '초급': {'attempts': 0, 'correct': 0, 'total_questions': 0, 'accuracy': 0.0, 'has_data': false},
            '중급': {'attempts': 0, 'correct': 0, 'total_questions': 0, 'accuracy': 0.0, 'has_data': false},
            '고급': {'attempts': 0, 'correct': 0, 'total_questions': 0, 'accuracy': 0.0, 'has_data': false},
          }
        };
      });
    } finally {
      setState(() {
        isLoadingQuizStats = false;
      });
    }
  }

  // 테스트 데이터 생성 (백엔드 API로 대체 예정)
  Future<void> _generateTestDataIfNeeded() async {
    try {
      print('📊 테스트 데이터 생성 (백엔드 API 필요)');
      // TODO: 백엔드에서 테스트 데이터 생성 API 호출
    } catch (e) {
      print('❌ 테스트 데이터 생성 실패: $e');
    }
  }

  // 닉네임 수정 시작
  void _startEditingNickname(String currentNickname) {
    setState(() {
      isEditingNickname = true;
      _nicknameController.text = currentNickname;
    });
  }

  // 닉네임 수정 취소
  void _cancelEditingNickname() {
    setState(() {
      isEditingNickname = false;
      _nicknameController.clear();
    });
  }

  // 닉네임 수정 저장
  Future<void> _saveNickname() async {
    final newNickname = _nicknameController.text.trim();
    
    if (newNickname.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('닉네임을 입력해주세요'),
          backgroundColor: Color(0xFFE53E3E),
        ),
      );
      return;
    }

    if (newNickname.length < 2 || newNickname.length > 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('닉네임은 2-10자 사이여야 합니다'),
          backgroundColor: Color(0xFFE53E3E),
        ),
      );
      return;
    }

    try {
      final authService = AuthService();
      final token = await authService.getToken();
      
      if (token != null) {
        // 여기서는 로컬에서만 업데이트 (실제로는 백엔드 API 호출 필요)
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        
        // 사용자 정보 업데이트
        if (authProvider.user != null) {
          final updatedUser = authProvider.user!.copyWith(nickname: newNickname);
          authProvider.updateUser(updatedUser);
        }
        
        setState(() {
          isEditingNickname = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('닉네임이 "$newNickname"으로 변경되었습니다'),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 3),
          ),
        );
        
        _nicknameController.clear();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('닉네임 변경 실패: $e'),
          backgroundColor: const Color(0xFFE53E3E),
        ),
      );
    }
  }


  // 레벨별 학습 구조 정의
  final Map<int, List<String>> levelStructure = {
    1: ['ㄱ', 'ㄲ', 'ㄴ', 'ㄷ', 'ㄸ', 'ㄹ', 'ㅁ', 'ㅂ', 'ㅃ', 'ㅅ', 'ㅆ'], // 기초 자음 + 된소리 (11개)
    2: ['ㅇ', 'ㅈ', 'ㅉ', 'ㅊ', 'ㅋ', 'ㅌ', 'ㅍ', 'ㅎ'], // 고급 자음 (8개)
    3: ['ㅏ', 'ㅑ', 'ㅓ', 'ㅕ', 'ㅗ', 'ㅛ', 'ㅜ', 'ㅠ', 'ㅡ', 'ㅣ'], // 기본 모음 (10개)
    4: ['ㅐ', 'ㅒ', 'ㅔ', 'ㅖ'], // 이중 모음 (4개)
    5: ['ㅘ', 'ㅙ', 'ㅚ', 'ㅝ', 'ㅞ', 'ㅟ', 'ㅢ'], // 복합 모음 (7개)
  };

  String _getLevelDescription(int level) {
    switch (level) {
      case 1:
        return '기초 자음 + 된소리 (ㄱ~ㅆ) 11개';
      case 2:
        return '고급 자음 (ㅇ~ㅎ) 8개';
      case 3:
        return '기본 모음 (ㅏ~ㅣ) 10개';
      case 4:
        return '이중 모음 (ㅐ,ㅒ,ㅔ,ㅖ) 4개';
      case 5:
        return '복합 모음 (ㅘ,ㅙ,ㅚ,ㅝ,ㅞ,ㅟ,ㅢ) 7개';
      default:
        return '학습 중';
    }
  }

  double _calculateProgressPercentage() {
    if (userProgress == null) return 0.0;
    
    final completedLessons = List<String>.from(userProgress!['completed_lessons'] ?? []);
    const totalLessons = 40; // 전체 학습 항목 수 (11+8+10+4+7=40)
    
    return (completedLessons.length / totalLessons * 100).clamp(0.0, 100.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF2D3748)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '마이페이지',
          style: GoogleFonts.notoSans(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF2D3748),
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 프로필 카드
            _buildProfileCard(),
            
            const SizedBox(height: 20),
            
            // 학습 진도 카드
            _buildProgressCard(),
            
            const SizedBox(height: 20),
            
            // 레벨별 진도 카드
            _buildLevelProgressCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4299E1), Color(0xFF9F7AEA)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4299E1).withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // 프로필 아이콘
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(40),
                ),
                child: const Icon(
                  Icons.person,
                  size: 40,
                  color: Colors.white,
                ),
              ),
              
              const SizedBox(height: 16),
              
              // 닉네임
              if (isEditingNickname)
                Container(
                  width: 200,
                  child: TextField(
                    controller: _nicknameController,
                    style: GoogleFonts.notoSans(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      border: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.7)),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white, width: 2),
                      ),
                      hintText: '닉네임 입력',
                      hintStyle: GoogleFonts.notoSans(
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                    maxLength: 10,
                    buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                  ),
                )
              else
                GestureDetector(
                  onTap: () => _startEditingNickname(
                    authProvider.user?.nickname ?? authProvider.user?.username ?? 'Unknown'
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        authProvider.user?.nickname ?? authProvider.user?.username ?? 'Unknown',
                        style: GoogleFonts.notoSans(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.edit,
                        color: Colors.white.withOpacity(0.8),
                        size: 20,
                      ),
                    ],
                  ),
                ),
              
              const SizedBox(height: 8),
              
              // 닉네임 수정 버튼들
              if (isEditingNickname)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: _cancelEditingNickname,
                      child: Text(
                        '취소',
                        style: GoogleFonts.notoSans(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: _saveNickname,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF4299E1),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Text(
                        '저장',
                        style: GoogleFonts.notoSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                )
              else
                // 아이디
                Text(
                  '@${authProvider.user?.username ?? 'unknown'}',
                  style: GoogleFonts.notoSans(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProgressCard() {
    if (isLoadingProgress) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final progressPercentage = _calculateProgressPercentage();
    final currentLevel = userProgress?['level'] ?? 1;
    final totalScore = userProgress?['total_score'] ?? 0;
    final completedLessons = List<String>.from(userProgress?['completed_lessons'] ?? []);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.trending_up,
                color: Color(0xFF4299E1),
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                '학습 진도',
                style: GoogleFonts.notoSans(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2D3748),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // 현재 레벨
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '현재 레벨',
                    style: GoogleFonts.notoSans(
                      fontSize: 14,
                      color: const Color(0xFF718096),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Level $currentLevel',
                    style: GoogleFonts.notoSans(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF4299E1),
                    ),
                  ),
                  Text(
                    _getLevelDescription(currentLevel),
                    style: GoogleFonts.notoSans(
                      fontSize: 12,
                      color: const Color(0xFF718096),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '총 점수',
                    style: GoogleFonts.notoSans(
                      fontSize: 14,
                      color: const Color(0xFF718096),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$totalScore점',
                    style: GoogleFonts.notoSans(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // 진도율
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '전체 진도',
                    style: GoogleFonts.notoSans(
                      fontSize: 14,
                      color: const Color(0xFF718096),
                    ),
                  ),
                  Text(
                    '${progressPercentage.toStringAsFixed(1)}%',
                    style: GoogleFonts.notoSans(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF4299E1),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                height: 8,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progressPercentage / 100,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4299E1), Color(0xFF9F7AEA)],
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${completedLessons.length}/35 완료',
                style: GoogleFonts.notoSans(
                  fontSize: 12,
                  color: const Color(0xFF718096),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLevelProgressCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 탭 전환 버튼들
          Row(
            children: [
              // 레벨별 진도 탭
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      showQuizStats = false;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: !showQuizStats ? const Color(0xFF4299E1) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF4299E1),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.school,
                          color: !showQuizStats ? Colors.white : const Color(0xFF4299E1),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '레벨별 진도',
                          style: GoogleFonts.notoSans(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: !showQuizStats ? Colors.white : const Color(0xFF4299E1),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // 퀴즈모드 통계 탭
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      showQuizStats = true;
                    });
                    // 퀴즈 통계 탭 클릭 시 데이터 새로고침
                    _loadQuizStatistics();
                    
                    // 테스트 데이터 생성 (임시)
                    _generateTestDataIfNeeded();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: showQuizStats ? const Color(0xFF9F7AEA) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF9F7AEA),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.quiz,
                          color: showQuizStats ? Colors.white : const Color(0xFF9F7AEA),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '퀴즈모드 통계',
                          style: GoogleFonts.notoSans(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: showQuizStats ? Colors.white : const Color(0xFF9F7AEA),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // 탭에 따른 내용 표시
          if (!showQuizStats) ...[
            // 레벨별 진도 표시
            ...List.generate(5, (index) {
            final level = index + 1;
            final levelItems = levelStructure[level] ?? [];
            final completedLessons = List<String>.from(userProgress?['completed_lessons'] ?? []);
            final completedInLevel = levelItems.where((item) => completedLessons.contains(item)).length;
            final progressInLevel = levelItems.isEmpty ? 0.0 : (completedInLevel / levelItems.length);
            
            // 스킵된 항목 개수 계산 (해당 레벨에서) - 임시로 0으로 설정
            final Set<String> skippedItems = <String>{}; // 빈 Set으로 초기화
            final skippedInLevel = levelItems.where((item) => skippedItems.contains(item)).length;
            
            // 복습 횟수 계산 (완료된 레슨 수를 기반으로 추정)
            final reviewCount = _calculateReviewCount(level, completedLessons);
            
            return Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: progressInLevel == 1.0 
                      ? const Color(0xFF10B981).withOpacity(0.3)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: progressInLevel == 1.0 
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFF4299E1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                '$level',
                                style: GoogleFonts.notoSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Level $level',
                                style: GoogleFonts.notoSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF2D3748),
                                ),
                              ),
                              Text(
                                _getLevelDescription(level),
                                style: GoogleFonts.notoSans(
                                  fontSize: 12,
                                  color: const Color(0xFF718096),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$completedInLevel/${levelItems.length}',
                            style: GoogleFonts.notoSans(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: progressInLevel == 1.0 
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFF4299E1),
                            ),
                          ),
                          Text(
                            '완료',
                            style: GoogleFonts.notoSans(
                              fontSize: 12,
                              color: const Color(0xFF718096),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // 진도 바
                  Container(
                    width: double.infinity,
                    height: 8,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: progressInLevel,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: progressInLevel == 1.0 
                                ? [const Color(0xFF10B981), const Color(0xFF059669)]
                                : [const Color(0xFF4299E1), const Color(0xFF3182CE)],
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // 복습 정보 및 상태
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          // 복습 정보
                          Icon(
                            Icons.refresh,
                            size: 16,
                            color: const Color(0xFF718096),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '복습 ${reviewCount}회',
                            style: GoogleFonts.notoSans(
                              fontSize: 12,
                              color: const Color(0xFF718096),
                            ),
                          ),
                          
                          // 스킵 정보 추가
                          if (skippedInLevel > 0) ...[
                            const SizedBox(width: 12),
                            Icon(
                              Icons.skip_next,
                              size: 16,
                              color: Colors.orange,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '스킵 ${skippedInLevel}개',
                              style: GoogleFonts.notoSans(
                                fontSize: 12,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: progressInLevel == 1.0 
                              ? const Color(0xFF10B981).withOpacity(0.1)
                              : progressInLevel > 0 
                                  ? const Color(0xFF4299E1).withOpacity(0.1)
                                  : const Color(0xFF718096).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          progressInLevel == 1.0 
                              ? '완료'
                              : progressInLevel > 0 
                                  ? '진행중'
                                  : '시작 전',
                          style: GoogleFonts.notoSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: progressInLevel == 1.0 
                                ? const Color(0xFF10B981)
                                : progressInLevel > 0 
                                    ? const Color(0xFF4299E1)
                                    : const Color(0xFF718096),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
          ] else ...[
            // 퀴즈모드 통계 표시
            _buildQuizStatsContent(),
          ],
        ],
      ),
    );
  }

  // 퀴즈모드 통계 내용 빌드
  Widget _buildQuizStatsContent() {
    if (isLoadingQuizStats) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    return Column(
      children: [
        // 낱말퀴즈 통계
        _buildQuizStatCard(
          '낱말퀴즈',
          '29개 문제',
          '자음과 모음 (된소리 포함)',
          const Color(0xFF6366F1),
          Icons.text_fields,
        ),
        const SizedBox(height: 12),
        
        // 초급 퀴즈 통계
        _buildQuizStatCard(
          '초급',
          '10개 문제',
          '받침 없는 글자 (된소리 포함)',
          const Color(0xFF10B981),
          Icons.looks_one,
        ),
        const SizedBox(height: 12),
        
        // 중급 퀴즈 통계
        _buildQuizStatCard(
          '중급',
          '5개 문제',
          '받침 있는 글자',
          const Color(0xFFF59E0B),
          Icons.looks_two,
        ),
        const SizedBox(height: 12),
        
        // 고급 퀴즈 통계
        _buildQuizStatCard(
          '고급',
          '5개 문제',
          '단어 표현',
          const Color(0xFFE53E3E),
          Icons.looks_3,
        ),
      ],
    );
  }

  // 개별 퀴즈 통계 카드 빌드
  Widget _buildQuizStatCard(String title, String problemCount, String description, Color color, IconData icon) {
    // 실제 퀴즈 통계 데이터 가져오기
    final modeStats = quizStatistics?['mode_statistics']?[title];
    final attempts = modeStats?['attempts'] ?? 0;
    final correct = modeStats?['correct'] ?? 0;
    final accuracy = modeStats?['accuracy'] ?? 0.0;
    final hasData = modeStats?['has_data'] ?? false;
    
    // 데이터가 있는지 확인
    final displayAttempts = hasData ? attempts : 0;
    final displayCorrect = hasData ? correct : 0;
    final displayAccuracy = hasData ? accuracy : 0.0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 아이콘
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          
          // 퀴즈 정보
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.notoSans(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF2D3748),
                      ),
                    ),
                    Text(
                      problemCount,
                      style: GoogleFonts.notoSans(
                        fontSize: 12,
                        color: const Color(0xFF718096),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.notoSans(
                    fontSize: 12,
                    color: const Color(0xFF718096),
                  ),
                ),
                const SizedBox(height: 8),
                
                // 통계 정보 (실제 데이터)
                Row(
                  children: [
                    _buildStatItem('시도', '${displayAttempts}회', color),
                    const SizedBox(width: 16),
                    _buildStatItem('정답', '${displayCorrect}개', color),
                    const SizedBox(width: 16),
                    _buildStatItem('정확도', '${displayAccuracy.toStringAsFixed(1)}%', color),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 통계 항목 빌드
  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.notoSans(
            fontSize: 10,
            color: const Color(0xFF9CA3AF),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.notoSans(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  // 복습 횟수 계산 함수
  int _calculateReviewCount(int level, List<String> completedLessons) {
    final levelItems = levelStructure[level] ?? [];
    final completedInLevel = levelItems.where((item) => completedLessons.contains(item)).length;
    
    // 복습 횟수는 완료된 항목 수를 기반으로 추정
    // 예: 레벨 1이 완전히 완료되면 1회 복습으로 간주
    if (completedInLevel == 0) return 0;
    if (completedInLevel == levelItems.length) {
      // 완전히 완료된 레벨은 최소 1회 복습
      return 1 + (completedLessons.length ~/ 10); // 전체 진도에 따라 추가 복습 횟수 계산
    }
    return 0; // 진행 중인 레벨은 아직 복습 횟수 0
  }

}
