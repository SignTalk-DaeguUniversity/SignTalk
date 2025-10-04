import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../services/progress_service.dart';
import '../services/auth_service.dart';

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

  @override
  void initState() {
    super.initState();
    _loadUserProgress();
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
    1: ['ㄱ', 'ㄴ', 'ㄷ', 'ㄹ', 'ㅁ', 'ㅂ', 'ㅅ'], // 기초 자음 (7개)
    2: ['ㅇ', 'ㅈ', 'ㅊ', 'ㅋ', 'ㅌ', 'ㅍ', 'ㅎ'], // 고급 자음 (7개)
    3: ['ㅏ', 'ㅑ', 'ㅓ', 'ㅕ', 'ㅗ', 'ㅛ', 'ㅜ', 'ㅠ', 'ㅡ', 'ㅣ'], // 기본 모음 (10개)
    4: ['ㅐ', 'ㅒ', 'ㅔ', 'ㅖ'], // 이중 모음 (4개)
    5: ['ㅘ', 'ㅙ', 'ㅚ', 'ㅝ', 'ㅞ', 'ㅟ', 'ㅢ'], // 복합 모음 (7개)
  };

  String _getLevelDescription(int level) {
    switch (level) {
      case 1:
        return '기초 자음 (ㄱ~ㅅ)';
      case 2:
        return '고급 자음 (ㅇ~ㅎ)';
      case 3:
        return '기본 모음 (ㅏ~ㅣ)';
      case 4:
        return '이중 모음 (ㅐ,ㅒ,ㅔ,ㅖ)';
      case 5:
        return '복합 모음 (ㅘ,ㅙ,ㅚ,ㅝ,ㅞ,ㅟ,ㅢ)';
      default:
        return '학습 중';
    }
  }

  double _calculateProgressPercentage() {
    if (userProgress == null) return 0.0;
    
    final completedLessons = List<String>.from(userProgress!['completed_lessons'] ?? []);
    const totalLessons = 35; // 전체 학습 항목 수
    
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
          Row(
            children: [
              const Icon(
                Icons.school,
                color: Color(0xFF4299E1),
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                '레벨별 진도',
                style: GoogleFonts.notoSans(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2D3748),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // 레벨별 진도 표시
          ...List.generate(5, (index) {
            final level = index + 1;
            final levelItems = levelStructure[level] ?? [];
            final completedLessons = List<String>.from(userProgress?['completed_lessons'] ?? []);
            final completedInLevel = levelItems.where((item) => completedLessons.contains(item)).length;
            final progressInLevel = levelItems.isEmpty ? 0.0 : (completedInLevel / levelItems.length);
            
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
        ],
      ),
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
