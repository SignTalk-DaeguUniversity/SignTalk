import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:mjpeg_view/mjpeg_view.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'providers/auth_provider.dart';
import 'services/progress_service.dart';
import 'services/quiz_result_service.dart';
import 'services/quiz_service.dart';
import 'services/jamo_service.dart';
import 'screens/auth_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/my_page_screen.dart';
import 'services/recognition_service.dart';

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
        theme: ThemeData(
          primarySwatch: Colors.blue,
          textTheme: GoogleFonts.notoSansTextTheme(),
          fontFamily: GoogleFonts.notoSans().fontFamily,
        ),
        home: const SplashScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class SignTalkHomePage extends StatefulWidget {
  const SignTalkHomePage({super.key});

  @override
  State<SignTalkHomePage> createState() => _SignTalkHomePageState();

  // 스킵된 항목 접근을 위한 정적 메서드
  static Set<String> getSkippedItems() {
    return _SignTalkHomePageState._skippedItems;
  }
}

class _SignTalkHomePageState extends State<SignTalkHomePage> {
  bool isLearningMode = true;
  bool isQuizStarted = false;
  bool showQuizResult = false;
  String selectedQuizType = '';
  int currentQuestionIndex = 0;
  int get totalQuestions => _getCurrentQuizData().length;
  int timeRemaining = 25;
  Timer? _timer;
  int correctAnswers = 0;
  int totalTimeSpent = 0;
  DateTime? quizStartTime;

  // 순차 인식 퀴즈 관련 상태
  bool isSequentialQuiz = false;
  String currentQuizWord = '';
  List<String> expectedSequence = [];
  int currentSequenceStep = 0;
  bool isSequenceCompleted = false;
  List<String> _currentQuizProblems = [];

  // 낱말퀴즈용 섞인 문제 데이터
  List<Map<String, String>> _shuffledQuizData = [];

  // 백엔드 API 연동을 위한 변수들
  String? _currentSessionId;
  String? _currentQuizMode;
  int _questionStartTime = 0;

  // 자모 분해 백그라운드 처리용 변수들
  List<String>? _currentJamoSequence; // 현재 문제의 자모 순서
  int _currentJamoIndex = 0; // 현재 기대하는 자모 인덱스

  // 현재 레벨 가져오기 (백엔드 API용)
  int _getCurrentLevel() {
    final levelProgress = _calculateLevelProgress();
    return levelProgress['level'] ?? 1;
  }

  // 현재 퀴즈 데이터 가져오기 (백엔드에서 받은 _shuffledQuizData 사용)
  List<Map<String, String>> _getCurrentQuizData() {
    if (_shuffledQuizData.isNotEmpty) {
      return _shuffledQuizData;
    }

    // 백엔드 데이터가 없으면 폴백 데이터 사용
    return _generateFallbackQuestions(selectedQuizType);
  }

  // 안전한 현재 문제 데이터 가져오기
  Map<String, String>? _getCurrentQuestion() {
    final data = _getCurrentQuizData();
    if (currentQuestionIndex >= 0 && currentQuestionIndex < data.length) {
      return data[currentQuestionIndex];
    }
    return null;
  }

  // 카메라 스트림 관련 상태
  bool isCameraOn = false;
  String currentLanguage = 'ksl'; // 'ksl' 또는 'asl'
  String workingStreamUrl = ''; // 작동하는 스트림 URL

  // 디바이스 카메라 관련 상태
  bool useDeviceCamera = false; // 디바이스 카메라 사용 여부
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;

  // 인식 결과 관련 상태
  String currentRecognition = '';
  String recognitionString = '';
  Timer? _recognitionTimer;
  Timer? _sequenceAnalysisTimer; // 시퀀스 분석용 타이머
  String? _lastAnalyzedTarget; // 마지막 분석 목표

  // 진도 관련 상태
  Map<String, dynamic>? userProgress;
  bool isLoadingProgress = false;

  // 손모양 분석 관련 상태
  Map<String, dynamic>? handAnalysis;
  bool isAnalyzing = false;
  String? currentSessionId;
  int? currentLearningSessionId; // 학습 세션 ID
  DateTime? sessionStartTime; // 세션 시작 시간
  int sessionAttempts = 0; // 세션 시도 횟수
  int sessionCorrectAttempts = 0; // 세션 정답 횟수

  // 퀴즈 정답 관련 상태
  bool showCorrectAnswer = false;
  bool isAnswerCorrect = false;
  Timer? _correctAnswerTimer;

  // 학습 진도 관련 상태
  int currentLearningStep = 0; // 현재 학습 단계 (0부터 시작)
  bool isLearningComplete = false; // 학습 완료 여부
  DateTime? lastProgressUpdate; // 마지막 진도 업데이트 시간
  bool isReviewMode = false; // 복습 모드 여부
  int? reviewLevelStep; // 복습 모드에서의 현재 단계

  Map<int, List<dynamic>>? curriculumData; // 백엔드에서 가져온 커리큘럼 데이터
  bool isLoadingCurriculum = false; // 커리큘럼 로딩 상태

  // 레벨별 학습 구조 정의
  final Map<int, List<String>> levelStructure = {
    1: [
      'ㄱ',
      'ㄲ',
      'ㄴ',
      'ㄷ',
      'ㄸ',
      'ㄹ',
      'ㅁ',
      'ㅂ',
      'ㅃ',
      'ㅅ',
      'ㅆ',
    ], // 기초 자음 + 된소리 (11개)
    2: ['ㅇ', 'ㅈ', 'ㅉ', 'ㅊ', 'ㅋ', 'ㅌ', 'ㅍ', 'ㅎ'], // 고급 자음 + 된소리 (8개)
    3: ['ㅏ', 'ㅑ', 'ㅓ', 'ㅕ', 'ㅗ', 'ㅛ', 'ㅜ', 'ㅠ', 'ㅡ', 'ㅣ'], // 기본 모음 (10개)
    4: ['ㅐ', 'ㅒ', 'ㅔ', 'ㅖ'], // 이중 모음 (4개)
    5: ['ㅘ', 'ㅙ', 'ㅚ', 'ㅝ', 'ㅞ', 'ㅟ', 'ㅢ'], // 복합 모음 (7개)
  };
  // 전체 학습 순서 (레벨 순서대로 합친 것)
  final List<String> learningSequence = [
    // 레벨 1: 기초 자음 + 된소리 (11개)
    'ㄱ', 'ㄲ', 'ㄴ', 'ㄷ', 'ㄸ', 'ㄹ', 'ㅁ', 'ㅂ', 'ㅃ', 'ㅅ', 'ㅆ',
    // 레벨 2: 고급 자음 + 된소리 (8개)
    'ㅇ', 'ㅈ', 'ㅉ', 'ㅊ', 'ㅋ', 'ㅌ', 'ㅍ', 'ㅎ',
    // 레벨 3: 기본 모음 (10개)
    'ㅏ', 'ㅑ', 'ㅓ', 'ㅕ', 'ㅗ', 'ㅛ', 'ㅜ', 'ㅠ', 'ㅡ', 'ㅣ',
    // 레벨 4: 이중 모음 (6개)
    'ㅐ', 'ㅒ', 'ㅔ', 'ㅖ', 'ㅘ', 'ㅙ',
    // 레벨 5: 복합 모음 (5개)
    'ㅚ', 'ㅝ', 'ㅞ', 'ㅟ', 'ㅢ',
  ];

  // 한글 분해 함수 (유니코드 기반)
  List<String> decomposeHangul(String word) {
    List<String> result = [];

    // 한글 자음 테이블
    const List<String> chosung = [
      'ㄱ',
      'ㄲ',
      'ㄴ',
      'ㄷ',
      'ㄸ',
      'ㄹ',
      'ㅁ',
      'ㅂ',
      'ㅃ',
      'ㅅ',
      'ㅆ',
      'ㅇ',
      'ㅈ',
      'ㅉ',
      'ㅊ',
      'ㅋ',
      'ㅌ',
      'ㅍ',
      'ㅎ',
    ];

    // 한글 모음 테이블
    const List<String> jungsung = [
      'ㅏ',
      'ㅐ',
      'ㅑ',
      'ㅒ',
      'ㅓ',
      'ㅔ',
      'ㅕ',
      'ㅖ',
      'ㅗ',
      'ㅘ',
      'ㅙ',
      'ㅚ',
      'ㅛ',
      'ㅜ',
      'ㅝ',
      'ㅞ',
      'ㅟ',
      'ㅠ',
      'ㅡ',
      'ㅢ',
      'ㅣ',
    ];

    // 한글 받침 테이블
    const List<String> jongsung = [
      '',
      'ㄱ',
      'ㄲ',
      'ㄳ',
      'ㄴ',
      'ㄵ',
      'ㄶ',
      'ㄷ',
      'ㄹ',
      'ㄺ',
      'ㄻ',
      'ㄼ',
      'ㄽ',
      'ㄾ',
      'ㄿ',
      'ㅀ',
      'ㅁ',
      'ㅂ',
      'ㅄ',
      'ㅅ',
      'ㅆ',
      'ㅇ',
      'ㅈ',
      'ㅊ',
      'ㅋ',
      'ㅌ',
      'ㅍ',
      'ㅎ',
    ];

    for (int i = 0; i < word.length; i++) {
      int code = word.codeUnitAt(i);

      // 한글 완성형 범위 체크 (가-힣)
      if (code >= 0xAC00 && code <= 0xD7A3) {
        int base = code - 0xAC00;
        int cho = base ~/ (21 * 28);
        int jung = (base % (21 * 28)) ~/ 28;
        int jong = base % 28;

        result.add(chosung[cho]);
        result.add(jungsung[jung]);
        if (jong > 0) {
          result.add(jongsung[jong]);
        }
      } else {
        // 한글이 아닌 경우 그대로 추가
        result.add(word[i]);
      }
    }

    return result;
  }

  // 동적 문제 생성을 위한 자음/모음 풀
  final List<String> availableChosung = [
    'ㄱ',
    'ㄴ',
    'ㄷ',
    'ㄹ',
    'ㅁ',
    'ㅂ',
    'ㅅ',
    'ㅇ',
    'ㅈ',
    'ㅊ',
    'ㅋ',
    'ㅌ',
    'ㅍ',
    'ㅎ',
  ];

  final List<String> availableJungsung = [
    'ㅏ',
    'ㅑ',
    'ㅓ',
    'ㅕ',
    'ㅗ',
    'ㅛ',
    'ㅜ',
    'ㅠ',
    'ㅡ',
    'ㅣ',
    'ㅐ',
    'ㅔ',
  ];

  final List<String> availableJongsung = [
    'ㄱ',
    'ㄴ',
    'ㄷ',
    'ㄹ',
    'ㅁ',
    'ㅂ',
    'ㅅ',
    'ㅇ',
    'ㅈ',
    'ㅊ',
    'ㅋ',
    'ㅌ',
    'ㅍ',
    'ㅎ',
  ];

  // 동적 문제 생성 함수
  List<String> generateUniqueProblems(String level, int count) {
    List<String> problems = [];

    // 랜덤 셔플링으로 매번 다른 조합
    List<String> chosungPool = List.from(availableChosung)..shuffle();
    List<String> jungsungPool = List.from(availableJungsung)..shuffle();
    List<String> jongsungPool = List.from(availableJongsung)..shuffle();

    for (int i = 0; i < count; i++) {
      if (level == '초급') {
        // 받침 없는 글자 생성
        if (chosungPool.isEmpty || jungsungPool.isEmpty) break;

        String cho = chosungPool.removeAt(0);
        String jung = jungsungPool.removeAt(0);

        String word = _combineHangul(cho, jung, '');
        problems.add(word);
      } else if (level == '중급') {
        // 받침 있는 글자 생성 (자음, 모음, 받침 모두 중복 없이)
        if (chosungPool.isEmpty || jungsungPool.isEmpty || jongsungPool.isEmpty)
          break;

        String cho = chosungPool.removeAt(0);
        String jung = jungsungPool.removeAt(0);

        // 받침은 이미 사용된 자음과 다른 것으로 선택
        List<String> availableJong = jongsungPool
            .where((jong) => jong != cho)
            .toList();
        if (availableJong.isEmpty) {
          // 사용 가능한 받침이 없으면 받침 없는 글자로 생성
          String word = _combineHangul(cho, jung, '');
          problems.add(word);
        } else {
          String jong = availableJong.first;
          jongsungPool.remove(jong); // 사용된 받침 제거

          String word = _combineHangul(cho, jung, jong);
          problems.add(word);
        }
      } else if (level == '고급') {
        // 2글자 단어 생성
        if (chosungPool.length < 2 || jungsungPool.length < 2) break;

        String cho1 = chosungPool.removeAt(0);
        String jung1 = jungsungPool.removeAt(0);
        String cho2 = chosungPool.removeAt(0);
        String jung2 = jungsungPool.removeAt(0);

        String word1 = _combineHangul(cho1, jung1, '');
        String word2 = _combineHangul(cho2, jung2, '');

        problems.add(word1 + word2);
      }
    }

    return problems;
  }

  // 한글 조합 함수 (자음 + 모음 + 받침 → 완성형 한글)
  String _combineHangul(String cho, String jung, String jong) {
    const List<String> chosungList = [
      'ㄱ',
      'ㄲ',
      'ㄴ',
      'ㄷ',
      'ㄸ',
      'ㄹ',
      'ㅁ',
      'ㅂ',
      'ㅃ',
      'ㅅ',
      'ㅆ',
      'ㅇ',
      'ㅈ',
      'ㅉ',
      'ㅊ',
      'ㅋ',
      'ㅌ',
      'ㅍ',
      'ㅎ',
    ];

    const List<String> jungsungList = [
      'ㅏ',
      'ㅐ',
      'ㅑ',
      'ㅒ',
      'ㅓ',
      'ㅔ',
      'ㅕ',
      'ㅖ',
      'ㅗ',
      'ㅘ',
      'ㅙ',
      'ㅚ',
      'ㅛ',
      'ㅜ',
      'ㅝ',
      'ㅞ',
      'ㅟ',
      'ㅠ',
      'ㅡ',
      'ㅢ',
      'ㅣ',
    ];

    const List<String> jongsungList = [
      '',
      'ㄱ',
      'ㄲ',
      'ㄳ',
      'ㄴ',
      'ㄵ',
      'ㄶ',
      'ㄷ',
      'ㄹ',
      'ㄺ',
      'ㄻ',
      'ㄼ',
      'ㄽ',
      'ㄾ',
      'ㄿ',
      'ㅀ',
      'ㅁ',
      'ㅂ',
      'ㅄ',
      'ㅅ',
      'ㅆ',
      'ㅇ',
      'ㅈ',
      'ㅊ',
      'ㅋ',
      'ㅌ',
      'ㅍ',
      'ㅎ',
    ];

    int choIndex = chosungList.indexOf(cho);
    int jungIndex = jungsungList.indexOf(jung);
    int jongIndex = jong.isEmpty ? 0 : jongsungList.indexOf(jong);

    if (choIndex == -1 || jungIndex == -1 || jongIndex == -1) return '';

    int code = 0xAC00 + (choIndex * 21 * 28) + (jungIndex * 28) + jongIndex;
    return String.fromCharCode(code);
  }

  // 고급 문제 풀 (실제 단어들)
  final List<String> advancedProblemsPool = [
    '가족',
    '학교',
    '친구',
    '선생님',
    '사랑',
    '행복',
    '건강',
    '평화',
    '자유',
    '희망',
    '꿈',
    '미래',
    '과거',
    '현재',
    '시간',
    '공간',
    '음식',
    '물건',
    '사람',
    '동물',
    '식물',
    '바다',
    '하늘',
    '땅',
  ];

  // 낱말퀴즈용 로컬 데이터 (백엔드 연결 실패 시에만 사용)
  final Map<String, List<Map<String, String>>> quizData = {
    '낱말퀴즈': [
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
    // 초급, 중급, 고급은 백엔드 전용 - 로컬 데이터 제거됨
  };

  @override
  void initState() {
    super.initState();
    // 초기화 후 AuthProvider가 준비될 때까지 대기
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // AuthProvider 초기화를 위해 약간 대기
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _loadUserProgress();
        }
      });
    });
    _initializeCamera();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recognitionTimer?.cancel();
    _correctAnswerTimer?.cancel();
    _sequenceAnalysisTimer?.cancel();
    // 카메라는 앱 종료 시에만 dispose (재사용을 위해)
    _cameraController?.dispose();
    super.dispose();
  }

  // 카메라 초기화 및 플랫폼 감지 (지연 로딩)
  Future<void> _initializeCamera() async {
    // 이미 초기화되어 있으면 스킵 (캐싱)
    if (_isCameraInitialized && _cameraController != null) {
      print('✅ 카메라 이미 초기화됨 (캐시 사용)');
      return;
    }

    try {
      print('🔄 카메라 초기화 시작...');

      // 플랫폼 감지: 실제 기기인지 에뮬레이터인지 확인
      useDeviceCamera = await _isRealDevice();

      if (useDeviceCamera) {
        // 실제 기기: 디바이스 카메라 사용
        await _initializeDeviceCamera();
      }

      print('📱 카메라 모드: ${useDeviceCamera ? "디바이스 카메라" : "서버 스트림"}');
    } catch (e) {
      print('❌ 카메라 초기화 실패: $e');
      useDeviceCamera = false; // 실패 시 서버 스트림 사용
    }
  }

  // 실제 기기인지 확인
  Future<bool> _isRealDevice() async {
    try {
      // Android: 에뮬레이터에서는 서버 스트림 사용 (노트북 웹캠)
      if (Platform.isAndroid) {
        // 에뮬레이터에서는 서버 스트림으로 노트북 웹캠 사용
        print(' Android 에뮬레이터 감지 - 서버 스트림 모드 사용 (노트북 웹캠)');
        return false; // 서버 스트림으로 수어 인식
      }
      // iOS: 실제 기기에서는 디바이스 카메라 사용
      else if (Platform.isIOS) {
        return true; // 실제 기기에서는 디바이스 카메라 사용
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // 디바이스 카메라 초기화 (최적화)
  Future<void> _initializeDeviceCamera() async {
    try {
      // 카메라 권한 요청
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        print('❌ 카메라 권한이 거부되었습니다');
        return;
      }

      // 사용 가능한 카메라 목록 가져오기 (캐싱)
      if (_cameras == null || _cameras!.isEmpty) {
        _cameras = await availableCameras();
        if (_cameras == null || _cameras!.isEmpty) {
          print('❌ 사용 가능한 카메라가 없습니다');
          return;
        }
      }

      // 전면 카메라 우선 선택 (수어 인식용)
      CameraDescription selectedCamera = _cameras!.first;
      for (var camera in _cameras!) {
        if (camera.lensDirection == CameraLensDirection.front) {
          selectedCamera = camera;
          break;
        }
      }

      // 카메라 컨트롤러 초기화 (저해상도 + 빠른 포맷)
      _cameraController = CameraController(
        selectedCamera,
        ResolutionPreset.low, // 성능 향상: 저해상도 (수어 인식에 충분)
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420, // 빠른 처리
      );

      // 초기화 시작
      final initStartTime = DateTime.now();
      await _cameraController!.initialize();
      final initDuration = DateTime.now().difference(initStartTime);

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }

      print('✅ 디바이스 카메라 초기화 완료 (${initDuration.inMilliseconds}ms, 저해상도 모드)');
    } catch (e) {
      print('❌ 디바이스 카메라 초기화 실패: $e');
      if (mounted) {
        setState(() {
          _isCameraInitialized = false;
        });
      }
    }
  }

  // 사용자 진도 불러오기 (KSL 고정)
  Future<void> _loadUserProgress() async {
    // 로그인하지 않은 경우 진도를 불러오지 않음
    if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (!authProvider.isLoggedIn) {
      setState(() {
        userProgress = null;
        isLoadingProgress = false;
      });
      return;
    }

    setState(() {
      isLoadingProgress = true;
    });

    try {
      final result = await ProgressService.getProgress('ksl');
      if (result['success']) {
        setState(() {
          userProgress = result['progress'];
        });
      } else {
        setState(() {
          userProgress = null;
        });
      }
    } catch (e) {
      print('진도 불러오기 실패: $e');
      setState(() {
        userProgress = null;
      });
    } finally {
      setState(() {
        isLoadingProgress = false;
      });
    }
  }

  // 손모양 분석 수행 (학습 모드에서)
  Future<void> _analyzeHandShape() async {
    if (!isLearningMode) return;

    setState(() {
      isAnalyzing = true;
    });

    try {
      // 학습 목표 문자 가져오기
      final targetCharacter = getCurrentLearningCharacter();
      
      // 복합모음/쌍자음 리스트
      const sequenceSigns = ['ㄲ', 'ㄸ', 'ㅃ', 'ㅆ', 'ㅉ', 'ㅘ', 'ㅙ', 'ㅝ', 'ㅞ'];
      
      // 목표가 변경되었는지 확인
      if (_lastAnalyzedTarget != targetCharacter) {
        print('🔄 목표 변경 감지: $_lastAnalyzedTarget → $targetCharacter');
        _lastAnalyzedTarget = targetCharacter;
        
        // 시퀀스 사인이면 버퍼 초기화
        if (sequenceSigns.contains(targetCharacter)) {
          await RecognitionService.clearSequenceBuffer();
          // 주기적 분석 시작
          _startSequenceAnalysis(targetCharacter);
        } else {
          // 일반 사인이면 타이머 중지
          _stopSequenceAnalysis();
        }
      }
      
      // 복합모음/쌍자음인 경우 목표 문자를 그대로 사용
      final targetSign = sequenceSigns.contains(targetCharacter) 
          ? targetCharacter 
          : currentRecognition;
      
      print('🔍 손모양 분석 시작: $targetSign (목표: $targetCharacter, 인식: $currentRecognition)');
      
      // 현재 카메라 프레임 캡처 (서버 스트림 모드에서는 불가능하므로 null)
      String? imageData;
      // TODO: 카메라 컨트롤러에서 이미지 캡처 구현 필요
      // 현재는 서버 스트림 모드라 직접 캡처 불가
      
      final result = await RecognitionService.analyzeHandShape(
        targetSign: targetSign,
        language: 'ksl',
        sessionId: currentSessionId,
        imageData: imageData, // 이미지 데이터 전달
      );

      if (result['success']) {
        setState(() {
          handAnalysis = result['analysis'];
        });
        
        // 시퀀스 사인인 경우 수집 진행률 표시
        if (sequenceSigns.contains(targetCharacter)) {
          final analysis = result['analysis'];
          final isCollecting = analysis['collecting'] == true;
          final bufferSize = analysis['buffer_size'] ?? 0;
          
          if (isCollecting) {
            print('📊 시퀀스 수집 중: $bufferSize/5 프레임');
          } else if (analysis['predicted_sign'] != null) {
            print('✅ 시퀀스 예측 완료: ${analysis['predicted_sign']} (정확도: ${analysis['accuracy']}%)');
          }
        }
      }
    } catch (e) {
      print('손모양 분석 실패: $e');
    } finally {
      setState(() {
        isAnalyzing = false;
      });
    }
  }

  // 시퀀스 분석 시작 (주기적 호출)
  void _startSequenceAnalysis(String targetSign) {
    print('🎬 시퀀스 분석 타이머 시작: $targetSign');
    
    // 기존 타이머 중지
    _sequenceAnalysisTimer?.cancel();
    
    // 200ms마다 분석 요청 (초당 5프레임)
    _sequenceAnalysisTimer = Timer.periodic(
      const Duration(milliseconds: 200),
      (timer) async {
        if (!isLearningMode || getCurrentLearningCharacter() != targetSign) {
          // 학습 모드가 아니거나 목표가 변경되면 중지
          _stopSequenceAnalysis();
          return;
        }
        
        try {
          final result = await RecognitionService.analyzeSequenceContinuous(
            targetSign: targetSign,
            language: 'ksl',
            sessionId: currentSessionId,
          );
          
          if (result['success'] && mounted) {
            setState(() {
              handAnalysis = result['analysis'];
            });
          }
        } catch (e) {
          print('시퀀스 분석 오류: $e');
        }
      },
    );
  }

  // 시퀀스 분석 중지
  void _stopSequenceAnalysis() {
    print('⏹️ 시퀀스 분석 타이머 중지');
    _sequenceAnalysisTimer?.cancel();
    _sequenceAnalysisTimer = null;
  }

  // 퀴즈 모드용 손모양 분석 및 정답 체크
  Future<void> _analyzeHandShapeForQuiz() async {
    if (!isQuizStarted || currentRecognition.isEmpty) return;

    try {
      // 현재 문제 가져오기
      final currentQuestion = _getCurrentQuestion();
      if (currentQuestion == null) return;

      final targetSign = currentQuestion['question'] ?? '';
      if (targetSign.isEmpty) return;

      // 복합모음/쌍자음 리스트
      const sequenceSigns = ['ㄲ', 'ㄸ', 'ㅃ', 'ㅆ', 'ㅉ', 'ㅘ', 'ㅙ', 'ㅝ', 'ㅞ'];

      // 시퀀스 사인인 경우 백엔드 분석 필요
      if (sequenceSigns.contains(targetSign)) {
        final result = await RecognitionService.analyzeHandShape(
          targetSign: targetSign,
          language: 'ksl',
          imageData: null,
        );

        if (result['success']) {
          final analysis = result['analysis'];
          final isCorrect = analysis['is_correct'] == true;
          final accuracy = analysis['accuracy'] ?? 0.0;

          // 정답 조건: 정확도 80% 이상
          if (isCorrect && accuracy >= 80.0) {
            _handleCorrectAnswer();
          }
        }
      } else {
        // 일반 자모: 정적 모델 인식 결과로 판단
        if (currentRecognition == targetSign) {
          _handleCorrectAnswer();
        }
      }
    } catch (e) {
      print('퀴즈 손모양 분석 실패: $e');
    }
  }

  // 정답 처리
  void _handleCorrectAnswer() {
    if (showCorrectAnswer) return; // 이미 정답 처리됨

    setState(() {
      showCorrectAnswer = true;
      isAnswerCorrect = true;
      correctAnswers++;
    });

    // 2초 후 다음 문제로
    _correctAnswerTimer?.cancel();
    _correctAnswerTimer = Timer(const Duration(seconds: 2), () {
      _nextQuestion();
    });
  }

  // 학습 세션 시작
  Future<void> _startLearningSession() async {
    if (!isLearningMode) return;

    try {
      final result = await RecognitionService.startRecognitionSession(
        language: 'ksl',
        mode: 'learning',
      );

      if (result['success']) {
        setState(() {
          currentSessionId = result['session_id'];
        });
      }
    } catch (e) {
      print('학습 세션 시작 실패: $e');
    }
  }

  // 현재 레벨과 진도 계산
  Map<String, dynamic> _calculateLevelProgress() {
    if (userProgress == null) {
      // 백엔드 연결 실패 시 로컬 저장소에서 진도 복원 시도
      print('⚠️ userProgress가 null입니다. 로컬 상태 확인 중...');
      return {'level': 1, 'progress': 0, 'currentStep': 0};
    }

    final completedLessons = List<String>.from(
      userProgress!['completed_lessons'] ?? [],
    );
    Set<String> uniqueCompleted = completedLessons.toSet();

    // 학습 순서대로 몇 개까지 완료했는지 확인
    int completedCount = 0;
    for (int i = 0; i < learningSequence.length; i++) {
      if (uniqueCompleted.contains(learningSequence[i])) {
        completedCount = i + 1;
      } else {
        break; // 순서대로 완료하지 않았으면 중단
      }
    }

    // 레벨별로 진도 계산
    int currentLevel = 1;
    int levelProgress = 0;
    int totalCompleted = completedCount;

    for (int level = 1; level <= 5; level++) {
      int levelSize = levelStructure[level]!.length;

      if (totalCompleted >= levelSize) {
        // 이 레벨 완료
        totalCompleted -= levelSize;
        currentLevel = level + 1;
        levelProgress = 0;
      } else {
        // 이 레벨에서 진행 중
        currentLevel = level;
        levelProgress = ((totalCompleted / levelSize) * 100).round();
        break;
      }
    }

    // 모든 레벨 완료 시
    if (currentLevel > 5) {
      currentLevel = 5;
      levelProgress = 100;
    }

    return {
      'level': currentLevel,
      'progress': levelProgress,
      'currentStep': completedCount.clamp(0, learningSequence.length),
    };
  }

  // 완료된 문자 수에 따른 올바른 레벨 계산
  int _calculateCorrectLevel(int completedCount) {
    // 레벨별 문자 수: 레벨1(11개), 레벨2(8개), 레벨3(10개), 레벨4(4개), 레벨5(7개) = 40개
    // 각 레벨을 완전히 마스터해야 다음 레벨로 진급
    if (completedCount < 11) return 1; // 0-10개: 레벨 1 (진행중)
    if (completedCount < 19) return 2; // 11-18개: 레벨 2 (레벨1 완료, 레벨2 진행중)
    if (completedCount < 29) return 3; // 19-28개: 레벨 3 (레벨2 완료, 레벨3 진행중)
    if (completedCount < 33) return 4; // 29-32개: 레벨 4 (레벨3 완료, 레벨4 진행중)
    if (completedCount < 40) return 5; // 33-39개: 레벨 5 (레벨4 완료, 레벨5 진행중)
    return 6; // 40개 이상: 전체 완료! 축하 다이얼로그 표시
  }

  // 백엔드 진도 데이터에서 현재 학습 단계 계산 (기존 함수 유지)
  int _calculateCurrentStepFromProgress() {
    return _calculateLevelProgress()['currentStep'];
  }

  // 현재 학습 단계의 수어 문자 가져오기
  String getCurrentLearningCharacter() {
    int step = isReviewMode && reviewLevelStep != null
        ? reviewLevelStep!
        : _calculateCurrentStepFromProgress();
    if (step >= learningSequence.length) {
      return '완료';
    }
    return learningSequence[step];
  }

  // 현재 학습 단계의 이미지 경로 가져오기
  String getCurrentLearningImagePath() {
    int step = isReviewMode && reviewLevelStep != null
        ? reviewLevelStep!
        : _calculateCurrentStepFromProgress();
    if (step >= learningSequence.length) {
      return '';
    }
    return 'assets/images/${learningSequence[step]}.jpg';
  }

  // 학습 진도 체크 및 업데이트
  void _checkLearningProgress() {
    if (!isLearningMode) return;

    // 쿨다운 체크 (3초 이내 중복 처리 방지)
    if (lastProgressUpdate != null &&
        DateTime.now().difference(lastProgressUpdate!).inSeconds < 3) {
      return;
    }

    String currentTarget = getCurrentLearningCharacter();
    
    // 복합모음/쌍자음 리스트
    const sequenceSigns = ['ㄲ', 'ㄸ', 'ㅃ', 'ㅆ', 'ㅉ', 'ㅘ', 'ㅙ', 'ㅝ', 'ㅞ'];
    
    // 복합모음/쌍자음인 경우 손모양 분석 결과로 판단
    bool isCorrect = false;
    
    if (sequenceSigns.contains(currentTarget)) {
      // 복합모음/쌍자음: 백엔드 분석 결과로 판단
      if (handAnalysis != null) {
        String? predictedSign = handAnalysis!['predicted_sign'];
        bool? isCorrectPrediction = handAnalysis!['is_correct'];
        double? accuracy = handAnalysis!['accuracy'] != null 
            ? (handAnalysis!['accuracy'] as num).toDouble() 
            : null;
        bool? isCollecting = handAnalysis!['collecting'];
        
        // 수집 중이면 아직 판단하지 않음
        if (isCollecting == true) {
          print('📊 시퀀스 수집 중... (${handAnalysis!['buffer_size']}/5 프레임)');
          return;
        }
        
        // 조건: 백엔드가 정답으로 예측 + 정확도 80% 이상
        if (isCorrectPrediction == true && accuracy != null && accuracy >= 80.0) {
          isCorrect = true;
          print('✅ 복합모음/쌍자음 통과: $currentTarget (예측: $predictedSign, 정확도: ${accuracy.toStringAsFixed(1)}%)');
        } else {
          print('❌ 복합모음/쌍자음 미통과: $currentTarget (예측: $predictedSign, 정확도: ${accuracy?.toStringAsFixed(1) ?? "N/A"}%)');
        }
      }
    } else {
      // 일반 자음/모음: 정확한 인식 필요
      if (currentRecognition.isEmpty) return;
      isCorrect = currentRecognition == currentTarget && currentRecognition.trim().isNotEmpty;
    }

    // 정답 체크
    if (isCorrect) {
      // 마지막 업데이트 시간 기록
      lastProgressUpdate = DateTime.now();

      if (isReviewMode) {
        // 복습 모드: 다음 문자로 이동
        _handleReviewProgress(currentTarget);
      } else {
        // 일반 학습 모드: 백엔드 진도 업데이트
        _updateBackendProgress(currentTarget);
      }

      // 인식 결과 초기화 (중복 처리 방지)
      setState(() {
        currentRecognition = '';
        handAnalysis = null; // 분석 결과도 초기화
      });
    }
  }

  // 복습 모드 진도 처리
  void _handleReviewProgress(String completedCharacter) {
    setState(() {
      reviewLevelStep = reviewLevelStep! + 1;
    });

    // 현재 복습 중인 레벨의 마지막 문자인지 확인
    int currentReviewLevel = _getCurrentReviewLevel();
    int levelEndIndex = _getLevelEndIndex(currentReviewLevel);

    if (reviewLevelStep! > levelEndIndex) {
      // 레벨 복습 완료
      setState(() {
        isReviewMode = false;
        reviewLevelStep = null;
        isLearningMode = false;
      });

      // 레벨 5 완료 시 특별한 축하 메시지
      if (currentReviewLevel == 5) {
        _showAllLevelsCompletedDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('레벨 $currentReviewLevel 복습을 완료했습니다!'),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } else {
      // 다음 문자로 진행
      String nextCharacter = learningSequence[reviewLevelStep!];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('정답! 다음은 $nextCharacter 입니다.'),
          backgroundColor: const Color(0xFF10B981),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  // 현재 복습 중인 레벨 계산
  int _getCurrentReviewLevel() {
    int step = reviewLevelStep!;
    int currentLevel = 1;
    int totalSteps = 0;

    for (int level = 1; level <= 5; level++) {
      int levelSize = levelStructure[level]!.length;
      if (step < totalSteps + levelSize) {
        return level;
      }
      totalSteps += levelSize;
      currentLevel = level + 1;
    }
    return currentLevel;
  }

  // 레벨의 마지막 인덱스 계산
  int _getLevelEndIndex(int level) {
    int endIndex = -1;
    for (int i = 1; i <= level; i++) {
      endIndex += levelStructure[i]!.length;
    }
    return endIndex;
  }

  // 스킵 시 로컬 진도 업데이트 (백엔드 API 없이 로컬에서만 처리)
  void _updateLocalProgressForSkip(String skippedCharacter) {
    try {
      print('🔄 스킵 로컬 진도 업데이트: $skippedCharacter');

      // 현재 진도에서 완료된 레슨 가져오기
      final completedLessons = List<String>.from(
        userProgress?['completed_lessons'] ?? [],
      );

      // 스킵된 항목을 완료된 레슨에 추가 (진도 계산을 위해)
      Set<String> uniqueLessons = completedLessons.toSet();
      if (!uniqueLessons.contains(skippedCharacter)) {
        uniqueLessons.add(skippedCharacter);
      }

      // 학습 순서대로 정렬
      List<String> sortedLessons = learningSequence
          .where((char) => uniqueLessons.contains(char))
          .toList();

      // 레벨 계산 (완료 + 스킵 포함)
      int currentLevel = _calculateCorrectLevel(sortedLessons.length);

      // 로컬 진도 업데이트 (점수는 추가하지 않음 - 스킵이므로)
      setState(() {
        userProgress = {
          ...userProgress ?? {},
          'completed_lessons': sortedLessons,
          'level': currentLevel,
          'total_score': userProgress?['total_score'] ?? 0, // 점수는 그대로 유지
        };
      });

      print('스킵 후 업데이트된 진도: ${userProgress?['completed_lessons']}');

      // 다음 학습 문자 확인
      final nextCharacter = getCurrentLearningCharacter();
      print('다음 학습 문자: $nextCharacter');

      // 쌍자음/복합모음 리스트
      const sequenceSigns = ['ㄲ', 'ㄸ', 'ㅃ', 'ㅆ', 'ㅉ', 'ㅘ', 'ㅙ', 'ㅝ', 'ㅞ'];
      
      // 다음 문자가 쌍자음/복합모음이면 버퍼 초기화
      if (sequenceSigns.contains(nextCharacter)) {
        print('🔄 스킵 후 다음 문자가 시퀀스 사인 → 버퍼 초기화: $nextCharacter');
        RecognitionService.clearSequenceBuffer();
      }

      if (nextCharacter == '완료') {
        // 모든 학습 완료 시 축하 다이얼로그 표시
        _showAllLevelsCompletedDialog();
      }
    } catch (e) {
      print('❌ 스킵 로컬 진도 업데이트 실패: $e');
    }
  }

  // 백엔드 진도 업데이트
  Future<void> _updateBackendProgress(String completedCharacter) async {
    try {
      print('🎯 진도 업데이트 시작: $completedCharacter');

      // 로컬 진도 먼저 업데이트
      final completedLessons = List<String>.from(
        userProgress?['completed_lessons'] ?? [],
      );
      Set<String> uniqueLessons = completedLessons.toSet();
      if (!uniqueLessons.contains(completedCharacter)) {
        uniqueLessons.add(completedCharacter);
      }

      List<String> sortedLessons = learningSequence
          .where((char) => uniqueLessons.contains(char))
          .toList();

      int currentLevel = _calculateCorrectLevel(sortedLessons.length);

      // 로컬 상태 즉시 업데이트
      setState(() {
        userProgress = {
          'completed_lessons': sortedLessons,
          'level': currentLevel,
          'total_score': (userProgress?['total_score'] ?? 0) + 10,
        };
      });

      // 다음 학습 문자 계산
      final nextCharacter = getCurrentLearningCharacter();
      print('🎯 다음 학습 문자: $nextCharacter');

      // 쌍자음/복합모음 리스트
      const sequenceSigns = ['ㄲ', 'ㄸ', 'ㅃ', 'ㅆ', 'ㅉ', 'ㅘ', 'ㅙ', 'ㅝ', 'ㅞ'];
      
      // 다음 문자가 쌍자음/복합모음이면 버퍼 초기화
      if (sequenceSigns.contains(nextCharacter)) {
        print('🔄 다음 문자가 시퀀스 사인 → 버퍼 초기화: $nextCharacter');
        await RecognitionService.clearSequenceBuffer();
      }

      // 성공 메시지 표시
      if (nextCharacter == '완료') {
        _showAllLevelsCompletedDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ 정답! "$completedCharacter" 학습 완료. 다음: $nextCharacter',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // 백엔드 업데이트 시도
      await ProgressService.saveRecognition(
        language: 'ksl',
        recognizedText: completedCharacter,
        confidenceScore: 1.0,
        sessionDuration: 0,
      );

      final result = await ProgressService.updateProgress('ksl', {
        'completed_lessons': sortedLessons,
        'level': currentLevel,
        'total_score': userProgress?['total_score'] ?? 0,
      });

      print('📡 백엔드 업데이트: ${result['success']}');
    } catch (e) {
      print('❌ 진도 업데이트 실패: $e');
    }
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
    _correctAnswerTimer?.cancel();

    final quizData = _getCurrentQuizData();
    if (currentQuestionIndex < quizData.length - 1) {
      setState(() {
        currentQuestionIndex++;

        // 새 문제 시작 시간 업데이트
        _questionStartTime = DateTime.now().millisecondsSinceEpoch;

        if (isSequentialQuiz) {
          // 순차 퀴즈: 다음 단어로 이동
          if (currentQuestionIndex < _currentQuizProblems.length) {
            currentQuizWord = _currentQuizProblems[currentQuestionIndex];
            expectedSequence = decomposeHangul(currentQuizWord);
            currentSequenceStep = 0;
            isSequenceCompleted = false;
            timeRemaining = 30;
          }
        } else {
          // 기존 퀴즈
          timeRemaining = 25;
        }

        showCorrectAnswer = false;
        isAnswerCorrect = false;
      });

      // 다음 문제의 자모 분해 준비
      _resetJamoSequence();
      _prepareJamoSequence();
      _startTimer();
    } else {
      // 퀴즈 완료
      _stopTimer();
      setState(() {
        isQuizStarted = false;
        showQuizResult = true;
        showCorrectAnswer = false;
        isAnswerCorrect = false;
        isSequentialQuiz = false; // 순차 퀴즈 모드 해제
        // 실제 소요시간 계산 (퀴즈 시작부터 현재까지)
        if (quizStartTime != null) {
          totalTimeSpent = DateTime.now().difference(quizStartTime!).inSeconds;
        }
      });

      // 퀴즈 결과 자동 저장
      _saveQuizResult();
    }
  }

  // 퀴즈 결과 저장
  Future<void> _saveQuizResult() async {
    try {
      // 모드명 매핑
      String mode = selectedQuizType;
      if (selectedQuizType == '날말퀴즈') {
        mode = '낱말퀴즈';
      }

      // 넘긴 문제 수 계산 (총 문제 - 정답 = 오답 + 넘긴 문제)
      int skippedProblems = totalQuestions - correctAnswers;

      // 정확도 계산
      double accuracy = totalQuestions > 0
          ? (correctAnswers / totalQuestions * 100)
          : 0;

      print('🎯 퀴즈 결과 저장 중...');
      print('📝 모드: $mode');
      print('📊 총 문제: $totalQuestions개');
      print('✅ 정답: $correctAnswers개');
      print('❌ 오답/넘긴: $skippedProblems개');
      print('📈 정확도: ${accuracy.toStringAsFixed(1)}%');
      print('⏱️ 소요시간: ${totalTimeSpent}초');

      bool success = await QuizResultService.saveQuizResult(
        mode: mode,
        totalProblems: totalQuestions,
        solvedProblems: correctAnswers,
        skippedProblems: skippedProblems,
        accuracy: accuracy,
        responseTime: totalTimeSpent,
      );

      if (success) {
        print('✅ 퀴즈 결과 저장 완료!');
      } else {
        print('❌ 퀴즈 결과 저장 실패');
      }
    } catch (e) {
      print('💥 퀴즈 결과 저장 오류: $e');
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
                    // Learning/Quiz mode selector
                    _buildModeSelector(),

                    const SizedBox(height: 16),
                    // Content based on mode
                    if (showQuizResult) ...[
                      // Quiz result screen
                      _buildQuizResultScreen(),
                    ] else if (isQuizStarted) ...[
                      // Quiz screen (문제 먼저)
                      _buildQuizScreen(),

                      const SizedBox(height: 16),

                      // Camera area (카메라 아래에)
                      Container(
                        height: 200,
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(horizontal: 0),
                        child: _buildCameraArea(),
                      ),

                      const SizedBox(height: 16),

                      // 퀴즈 모드 버튼들 (카메라 밑에)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // 퀴즈 중단 버튼
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  isQuizStarted = false;
                                  showQuizResult = false;
                                  selectedQuizType = "";
                                  currentQuestionIndex = 0;
                                  correctAnswers = 0;
                                  _timer?.cancel();
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("퀴즈를 중단했습니다"),
                                    backgroundColor: Colors.red,
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.stop,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      "퀴즈 중단",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // 스킵 버튼
                          Expanded(
                            child: GestureDetector(
                              onTap: _skipCurrentProblem,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                margin: const EdgeInsets.only(left: 8),
                                decoration: BoxDecoration(
                                  color: Colors.orange,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.skip_next,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      "스킵",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else if (isLearningMode) ...[
                      // Learning mode content (학습모드)
                      Container(
                        height: 200,
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(horizontal: 0),
                        child: _buildCameraArea(),
                      ),

                      const SizedBox(height: 16),

                      // Recognition result area
                      _buildRecognitionArea(),
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
              GestureDetector(
                onTap: () {
                  // 홈으로 리디렉션 (모든 상태 초기화)
                  setState(() {
                    isLearningMode = true;
                    isQuizStarted = false;
                    showQuizResult = false;
                    selectedQuizType = '';
                    currentQuestionIndex = 0;
                    correctAnswers = 0;
                    totalTimeSpent = 0;
                    isReviewMode = false;
                    reviewLevelStep = null;
                  });
                },
                child: ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFF6B73FF), Color(0xFF9F7AEA)],
                  ).createShader(bounds),
                  child: Text(
                    'SignTalk',
                    style: GoogleFonts.notoSans(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
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
              } else if (value == 'mypage') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MyPageScreen()),
                );
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'profile',
                enabled: false,
                child: Row(
                  children: [
                    const Icon(
                      Icons.person,
                      size: 18,
                      color: Color(0xFF4299E1),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      authProvider.user!.nickname ??
                          authProvider.user!.username,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3748),
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'mypage',
                child: Row(
                  children: [
                    Icon(
                      Icons.account_circle,
                      size: 18,
                      color: Color(0xFF4299E1),
                    ),
                    SizedBox(width: 8),
                    Text('마이페이지'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 18, color: Color(0xFFE53E3E)),
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
                    authProvider.user?.nickname ??
                        authProvider.user?.username ??
                        'Unknown',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.arrow_drop_down,
                    size: 18,
                    color: Colors.white,
                  ),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
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
                  // 퀴즈 모드 상태 초기화
                  isQuizStarted = false;
                  showQuizResult = false;
                  selectedQuizType = '';
                  currentQuestionIndex = 0;
                  correctAnswers = 0;
                  isSequentialQuiz = false;
                  showCorrectAnswer = false;
                  isAnswerCorrect = false;
                  _shuffledQuizData.clear();
                  _lastAnalyzedTarget = null; // 목표 초기화
                });
                _stopTimer(); // 타이머 정지
                _startLearningSession();
                
                // 현재 학습 문자가 시퀀스 사인이면 분석 시작
                final currentChar = getCurrentLearningCharacter();
                const sequenceSigns = ['ㄲ', 'ㄸ', 'ㅃ', 'ㅆ', 'ㅉ', 'ㅘ', 'ㅙ', 'ㅝ', 'ㅞ'];
                if (sequenceSigns.contains(currentChar)) {
                  Future.delayed(const Duration(milliseconds: 500), () {
                    _startSequenceAnalysis(currentChar);
                  });
                }
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
      child: isCameraOn
          ? (useDeviceCamera
                ? _buildDeviceCameraStream()
                : _buildCameraStream())
          : _buildCameraOffState(),
    );
  }

  // 디바이스 카메라 스트림 위젯
  Widget _buildDeviceCameraStream() {
    if (!_isCameraInitialized || _cameraController == null) {
      return Container(
        color: const Color(0xFFF0F0F0),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9F7AEA)),
              ),
              SizedBox(height: 16),
              Text(
                '디바이스 카메라 초기화 중...',
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          // 카메라 프리뷰
          SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: CameraPreview(_cameraController!),
          ),

          // 상태 표시 오버레이
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    '디바이스 카메라',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraStream() {
    // 작동하는 URL이 없으면 로딩 표시
    if (workingStreamUrl.isEmpty) {
      return Container(
        color: const Color(0xFFF0F0F0),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9F7AEA)),
              ),
              SizedBox(height: 16),
              Text(
                '서버 연결 중...',
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          // MJPEG 스트림 뷰어
          MjpegView(
            uri: workingStreamUrl,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
          // 학습 모드일 때 학습 이미지 표시 (왼쪽 상단)
          if (isLearningMode && getCurrentLearningCharacter() != '완료')
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    getCurrentLearningImagePath(),
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[200],
                        child: const Icon(
                          Icons.image_not_supported,
                          color: Colors.grey,
                          size: 20,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

          // 컨트롤 버튼들
          Positioned(
            top: 8,
            right: 8,
            child: Row(
              children: [
                // KSL 표시 (고정)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'KSL',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // 카메라 끄기 버튼
                GestureDetector(
                  onTap: _toggleCamera,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 하단 버튼들 (스킵 + 다음 문제)
          Positioned(
            bottom: 16,
            right: 16,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 학습모드일 때만 스킵 버튼 표시
                if (isLearningMode && getCurrentLearningCharacter() != '완료')
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          _handleSkipLearning();
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.skip_next,
                                color: Colors.white,
                                size: 18,
                              ),
                              SizedBox(width: 4),
                              Text(
                                '스킵',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraOffState() {
    return Column(
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
        const SizedBox(height: 8),
        Text(
          '${currentLanguage.toUpperCase()} 수어 인식 모드',
          style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
        ),
        const SizedBox(height: 20),
        // 카메라 켜기 버튼
        ElevatedButton.icon(
          onPressed: _toggleCamera,
          icon: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
          label: Text(
            isCameraOn ? '카메라 끄기' : '카메라 켜기',
            style: const TextStyle(color: Colors.white, fontSize: 14),
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
    );
  }

  Future<void> _toggleCamera() async {
    if (!isCameraOn) {
      // 카메라를 켤 때
      setState(() {
        isCameraOn = true;

        // 학습 모드 세션 설정 (카메라 켜기 시)
        if (isLearningMode && _currentSessionId == null) {
          _currentSessionId =
              'learning_${DateTime.now().millisecondsSinceEpoch}';
          _questionStartTime = DateTime.now().millisecondsSinceEpoch;
        }
      });

      // 카메라가 초기화되지 않았으면 초기화 (지연 로딩)
      if (!_isCameraInitialized && _cameraController == null) {
        await _initializeCamera();
      }

      if (useDeviceCamera) {
        // 디바이스 카메라 사용 시
        _startDeviceCameraRecognition();
      } else {
        // 서버 스트림 사용 시
        _findWorkingStreamUrl();
        _startRecognitionPolling();
      }
    } else {
      // 카메라를 끄 때 (카메라는 dispose하지 않고 재사용)
      setState(() {
        isCameraOn = false;
      });
      _stopRecognitionPolling();
      workingStreamUrl = '';
    }
  }

  // 디바이스 카메라 인식 시작
  void _startDeviceCameraRecognition() {
    if (!_isCameraInitialized || _cameraController == null) {
      print('❌ 디바이스 카메라가 초기화되지 않았습니다');
      return;
    }

    // 디바이스 카메라 사용 시 이미지 캡처 및 전송 시작
    _startImageCaptureAndUpload();
    print('✅ 디바이스 카메라 인식 시작');
  }

  // 이미지 캡처 및 업로드 시작
  void _startImageCaptureAndUpload() {
    _recognitionTimer?.cancel();
    _recognitionTimer = Timer.periodic(const Duration(seconds: 2), (
      timer,
    ) async {
      await _captureAndUploadImage();
    });
  }

  // 카메라 이미지 캡처 및 서버 업로드
  Future<void> _captureAndUploadImage() async {
    if (!_isCameraInitialized || _cameraController == null) {
      return;
    }

    try {
      // 이미지 캡처
      final XFile imageFile = await _cameraController!.takePicture();

      // 서버로 이미지 업로드
      await _uploadImageToServer(imageFile);
    } catch (e) {
      print('❌ 이미지 캡처 실패: $e');
    }
  }

  // 서버로 이미지 업로드
  Future<void> _uploadImageToServer(XFile imageFile) async {
    try {
      List<String> serverUrls = [
        'http://127.0.0.1:5002', // USB 디버깅 (ADB 포트 포워딩)
        'http://192.168.45.98:5002', // WiFi 연결 (노트북 실제 IP)
        'http://10.0.2.2:5002', // 에뮬레이터용
        'http://localhost:5002', // USB 디버깅 대안
      ];

      for (String baseUrl in serverUrls) {
        try {
          var request = http.MultipartRequest(
            'POST',
            Uri.parse('$baseUrl/upload_image/$currentLanguage'),
          );

          // 이미지 파일 추가
          request.files.add(
            await http.MultipartFile.fromPath('image', imageFile.path),
          );

          var response = await request.send().timeout(
            const Duration(seconds: 5),
          );

          if (response.statusCode == 200) {
            String responseBody = await response.stream.bytesToString();
            final data = jsonDecode(responseBody);

            if (data['success']) {
              setState(() {
                currentRecognition = data['recognized_character'] ?? '';
              });

              // 퀴즈 모드일 때 정답 확인
              if (isQuizStarted && currentRecognition.isNotEmpty) {
                _checkQuizAnswer();
              }

              // 학습 모드일 때 손모양 분석 및 진도 체크
              if (isLearningMode && currentRecognition.isNotEmpty) {
                _analyzeHandShape();
                _checkLearningProgress();
              }
            }
            return;
          }
        } catch (e) {
          print('❌ $baseUrl 이미지 업로드 실패: $e');
          continue;
        }
      }

      print('❌ 모든 서버에 이미지 업로드 실패');
    } catch (e) {
      print('❌ 이미지 업로드 처리 실패: $e');
    }
  }

  // 작동하는 스트림 URL 찾기 (캐싱 최적화)
  Future<void> _findWorkingStreamUrl() async {
    // 이미 작동하는 URL이 있으면 재사용 (캐싱)
    if (workingStreamUrl.isNotEmpty) {
      print('✅ 캐시된 스트림 URL 사용: $workingStreamUrl');
      return;
    }

    print('🔄 서버 스트림 URL 검색 중...');

    List<String> serverUrls = [
      'http://127.0.0.1:5002', // USB 디버깅 (ADB 포트 포워딩)
      'http://192.168.45.98:5002', // WiFi 연결 (노트북 실제 IP)
      'http://10.0.2.2:5002', // 에뮬레이터용
      'http://localhost:5002', // USB 디버깅 대안
    ];

    for (String baseUrl in serverUrls) {
      try {
        final testUrl = '$baseUrl/video_feed_$currentLanguage';
        final response = await http
            .head(Uri.parse(testUrl))
            .timeout(const Duration(seconds: 2)); // 타임아웃 단축

        if (response.statusCode == 200) {
          setState(() {
            workingStreamUrl = testUrl;
          });
          print('✅ 작동하는 스트림 URL 발견: $testUrl');
          return;
        }
      } catch (e) {
        // 에러 로그 최소화
        continue;
      }
    }

    print('❌ 모든 서버 URL 연결 실패');
  }

  // 인식 결과 폴링 시작 (간격 최적화)
  void _startRecognitionPolling() {
    _recognitionTimer?.cancel();
    _recognitionTimer = Timer.periodic(const Duration(milliseconds: 1500), (
      timer,
    ) {
      _fetchRecognitionResult();
    });
  }

  // 인식 결과 폴링 중지
  void _stopRecognitionPolling() {
    _recognitionTimer?.cancel();
    setState(() {
      currentRecognition = '';
      recognitionString = '';
    });
  }

  // 백엔드에서 인식 결과 가져오기 (캐시된 URL 우선 사용)
  Future<void> _fetchRecognitionResult() async {
    try {
      // 이미 작동하는 URL이 있으면 우선 사용
      if (workingStreamUrl.isNotEmpty) {
        String baseUrl = workingStreamUrl.split('/video_feed')[0];
        try {
          // 🆕 새로운 API 먼저 시도
          final response = await http
              .get(
                Uri.parse('$baseUrl/api/recognition/current/$currentLanguage'),
              )
              .timeout(const Duration(seconds: 1));

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            setState(() {
              currentRecognition = data['current_character'] ?? '';
              recognitionString = data['accumulated_string'] ?? '';
            });

            // 퀴즈 모드일 때 손모양 분석 및 정답 확인
            if (isQuizStarted && currentRecognition.isNotEmpty) {
              _analyzeHandShapeForQuiz();
            }

            // 학습 모드일 때 손모양 분석 및 진도 체크
            if (isLearningMode && currentRecognition.isNotEmpty) {
              _analyzeHandShape();
              _checkLearningProgress();
            }
            return;
          }
        } catch (e) {
          // 새 API 실패 시 기존 API로 폴백
          try {
            final response = await http
                .get(Uri.parse('$baseUrl/get_string/$currentLanguage'))
                .timeout(const Duration(seconds: 1));

            if (response.statusCode == 200) {
              final data = jsonDecode(response.body);
              setState(() {
                currentRecognition = data['current'] ?? '';
                recognitionString = data['string'] ?? '';
              });

              if (isQuizStarted && currentRecognition.isNotEmpty) {
                _checkQuizAnswer();
              }
              if (isLearningMode && currentRecognition.isNotEmpty) {
                _analyzeHandShape();
                _checkLearningProgress();
              }
              return;
            }
          } catch (e2) {
            print('❌ 캐시된 URL 실패: $e2');
          }
        }
      }

      // 캐시된 URL이 실패하면 모든 URL 시도
      List<String> serverUrls = [
        'http://127.0.0.1:5002', // USB 디버깅 (ADB 포트 포워딩)
        'http://192.168.45.98:5002', // WiFi 연결 (노트북 실제 IP)
        'http://10.0.2.2:5002', // 에뮬레이터용
        'http://localhost:5002', // USB 디버깅 대안
      ];

      for (String baseUrl in serverUrls) {
        try {
          // 🆕 새로운 API 먼저 시도
          final response = await http
              .get(
                Uri.parse('$baseUrl/api/recognition/current/$currentLanguage'),
              )
              .timeout(const Duration(seconds: 2));

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            setState(() {
              currentRecognition = data['current_character'] ?? '';
              recognitionString = data['accumulated_string'] ?? '';
            });

            if (isQuizStarted && currentRecognition.isNotEmpty) {
              _checkQuizAnswer();
            }
            if (isLearningMode && currentRecognition.isNotEmpty) {
              _analyzeHandShape();
              _checkLearningProgress();
            }
            return;
          }
        } catch (e) {
          // 새 API 실패 시 기존 API로 폴백
          try {
            final response = await http
                .get(Uri.parse('$baseUrl/get_string/$currentLanguage'))
                .timeout(const Duration(seconds: 2));

            if (response.statusCode == 200) {
              final data = jsonDecode(response.body);
              setState(() {
                currentRecognition = data['current'] ?? '';
                recognitionString = data['string'] ?? '';
              });

              if (isQuizStarted && currentRecognition.isNotEmpty) {
                _checkQuizAnswer();
              }
              if (isLearningMode && currentRecognition.isNotEmpty) {
                _analyzeHandShape();
                _checkLearningProgress();
              }
              return;
            }
          } catch (e2) {
            continue;
          }
        }
      }
    } catch (e) {
      // 에러 무시 (연결 실패는 정상적인 상황)
    }
  }

  // 퀴즈 정답 확인
  void _checkQuizAnswer() {
    if (selectedQuizType.isEmpty || showCorrectAnswer) return;

    if (isSequentialQuiz) {
      // 순차 인식 퀴즈 체크
      _checkSequentialAnswer();
    } else {
      // 기존 퀴즈 체크 + 자모 분해 처리
      final currentQuestion = _getCurrentQuestion();
      if (currentQuestion == null) return;

      String correctAnswer = currentQuestion['question']!;

      // 1. 자모 분해 모드 체크 (모든 퀴즈)
      if (_currentJamoSequence != null) {
        
        // 자모 순서대로 인식 체크
        bool isWordCompleted = _checkJamoSequence(currentRecognition);
        
        if (isWordCompleted) {
          // 단어 완성! 정답 처리
          setState(() {
            showCorrectAnswer = true;
            isAnswerCorrect = true;
            correctAnswers++;
          });

          // 2초 후 다음 문제로
          _correctAnswerTimer = Timer(const Duration(seconds: 2), () {
            _nextQuestion();
          });
        }
        // 자모가 일치하지 않으면 아무것도 하지 않음 (계속 기다림)
        
      } else {
        // 2. 기존 방식 (자모 분해 실패 시)
        if (currentRecognition == correctAnswer) {
          // 정답!
          setState(() {
            showCorrectAnswer = true;
            isAnswerCorrect = true;
            correctAnswers++;
          });

          // 2초 후 다음 문제로
          _correctAnswerTimer = Timer(const Duration(seconds: 2), () {
            _nextQuestion();
          });
        }
      }
    }
  }

  // 순차 인식 퀴즈 정답 체크
  void _checkSequentialAnswer() {
    if (currentSequenceStep >= expectedSequence.length || isSequenceCompleted)
      return;

    String expectedChar = expectedSequence[currentSequenceStep];

    if (currentRecognition == expectedChar) {
      setState(() {
        currentSequenceStep++;
      });

      if (currentSequenceStep >= expectedSequence.length) {
        // 모든 단계 완료!
        setState(() {
          isSequenceCompleted = true;
          showCorrectAnswer = true;
          isAnswerCorrect = true;
          correctAnswers++;
        });

        // 2초 후 다음 문제로
        _correctAnswerTimer = Timer(const Duration(seconds: 2), () {
          _nextQuestion();
        });
      } else {
        // 다음 단계로 진행
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ ${expectedChar} 정답! 다음: ${expectedSequence[currentSequenceStep]}',
            ),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }

  // 순차 퀴즈 시작
  void _startSequentialQuiz(String level) {
    List<String> problems;

    if (level == '고급') {
      // 고급은 실제 단어들에서 랜덤 선택
      List<String> shuffled = List.from(advancedProblemsPool)..shuffle();
      problems = shuffled.take(8).toList();
    } else {
      int count = level == '초급' ? 10 : (level == '중급' ? 10 : 8);
      problems = generateUniqueProblems(level, count);
    }

    if (problems.isEmpty) return;

    setState(() {
      isSequentialQuiz = true;
      selectedQuizType = level;
      currentQuizWord = problems[0];
      expectedSequence = decomposeHangul(currentQuizWord);
      currentSequenceStep = 0;
      isSequenceCompleted = false;
      currentQuestionIndex = 0;
      correctAnswers = 0;
      isQuizStarted = true;
      showQuizResult = false;
      timeRemaining = 30; // 순차 퀴즈는 30초
      quizStartTime = DateTime.now().toLocal(); // 퀴즈 시작 시간 기록 (로컬 타임존으로 변환)
    });

    // 생성된 문제들을 임시 저장
    _currentQuizProblems = problems;
    _startTimer();
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
                child: Text(
                  recognitionString.length > 0
                      ? '${recognitionString.length}개'
                      : '0개',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF718096),
                  ),
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
            child: isLearningMode
                ? _buildLearningModeRecognition()
                : _buildNormalRecognition(),
          ),
          const SizedBox(height: 16),
          _buildProgressDisplay(),
        ],
      ),
    );
  }

  // 학습 모드 인식 결과 (2분할)
  Widget _buildLearningModeRecognition() {
    return Row(
      children: [
        // 왼쪽: KSL 인식 결과
        Expanded(
          flex: 1,
          child: Container(
            height: double.infinity,
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (currentRecognition.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4299E1), Color(0xFF9F7AEA)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Text(
                          currentRecognition,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'KSL 인식',
                          style: TextStyle(fontSize: 10, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  const Icon(
                    Icons.timeline,
                    size: 24,
                    color: Color(0xFFCBD5E0),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '인식 중...',
                    style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ),
        // 구분선
        Container(
          width: 1,
          height: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 8),
          color: const Color(0xFFE2E8F0),
        ),
        // 오른쪽: 손모양 분석 결과
        Expanded(
          flex: 1,
          child: Container(
            height: double.infinity,
            padding: const EdgeInsets.all(8),
            child: _buildHandAnalysisResult(),
          ),
        ),
      ],
    );
  }

  // 일반 모드 인식 결과 (기존)
  Widget _buildNormalRecognition() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (currentRecognition.isNotEmpty) ...[
          // 인식된 결과 표시
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4299E1), Color(0xFF9F7AEA)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  currentRecognition,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'KSL 인식 결과',
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (recognitionString.isNotEmpty)
            Text(
              '전체: $recognitionString',
              style: const TextStyle(fontSize: 14, color: Color(0xFF4A5568)),
            ),
        ] else ...[
          // 기본 상태
          const Icon(Icons.timeline, size: 32, color: Color(0xFFCBD5E0)),
          const SizedBox(height: 8),
          Text(
            isCameraOn ? '수어를 인식 중입니다...' : '카메라를 켜주세요',
            style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
          ),
          const Text(
            '카메라 앞에서 수어를 보여주세요',
            style: TextStyle(color: Color(0xFFCBD5E0), fontSize: 12),
          ),
        ],
      ],
    );
  }

  // 손모양 분석 결과 표시
  Widget _buildHandAnalysisResult() {
    // 시퀀스 수집 중인지 확인
    final isCollecting = handAnalysis?['collecting'] == true;
    final bufferSize = handAnalysis?['buffer_size'] ?? 0;
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isAnalyzing) ...[
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(height: 4),
          const Text(
            '분석 중...',
            style: TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)),
          ),
        ] else if (isCollecting) ...[
          // 시퀀스 수집 진행률 표시
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  value: bufferSize / 5.0,
                  strokeWidth: 3,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4299E1)),
                ),
              ),
              Text(
                '$bufferSize',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4299E1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            '동작 수집 중',
            style: TextStyle(fontSize: 9, color: Color(0xFF4299E1)),
            textAlign: TextAlign.center,
          ),
          Text(
            '$bufferSize/5 프레임',
            style: const TextStyle(fontSize: 8, color: Color(0xFF9CA3AF)),
          ),
        ] else if (handAnalysis != null) ...[
          // 정확도 표시
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getAccuracyColor(
                handAnalysis!['accuracy'] ?? 0,
              ).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${handAnalysis!['accuracy']?.toStringAsFixed(1) ?? '0'}%',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _getAccuracyColor(handAnalysis!['accuracy'] ?? 0),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _getFeedbackMessage(handAnalysis!['feedback']),
            style: const TextStyle(fontSize: 9, color: Color(0xFF718096)),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ] else ...[
          const Icon(
            Icons.analytics_outlined,
            size: 20,
            color: Color(0xFFCBD5E0),
          ),
          const SizedBox(height: 4),
          const Text(
            '분석 대기',
            style: TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)),
          ),
        ],
      ],
    );
  }

  // 정확도에 따른 색상 반환
  Color _getAccuracyColor(double accuracy) {
    if (accuracy >= 90) return const Color(0xFF10B981); // 초록
    if (accuracy >= 80) return const Color(0xFF3B82F6); // 파랑
    if (accuracy >= 70) return const Color(0xFFF59E0B); // 주황
    return const Color(0xFFEF4444); // 빨강
  }

  // 피드백 메시지 반환
  String _getFeedbackMessage(Map<String, dynamic>? feedback) {
    if (feedback == null) return '';
    return feedback['message'] ?? '';
  }

  Widget _buildProgressDisplay() {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        // 로그인 상태가 변경되면 진도 다시 불러오기
        if (authProvider.isLoggedIn &&
            userProgress == null &&
            !isLoadingProgress) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _loadUserProgress();
          });
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0x05000000),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.trending_up,
                    color: const Color(0xFF4299E1),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '학습 진도',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3748),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4299E1).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'KSL',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4299E1),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (isLoadingProgress)
                const Center(child: CircularProgressIndicator(strokeWidth: 2))
              else if (authProvider.isLoggedIn && userProgress != null) ...[
                _buildProgressInfo(),
              ] else ...[
                _buildDefaultProgress(),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildProgressInfo() {
    final totalScore = userProgress!['total_score'] ?? 0;
    final completedLessons = userProgress!['completed_lessons'] ?? [];

    // 새로운 레벨 시스템으로 진도 계산
    final levelData = _calculateLevelProgress();
    final level = levelData['level'];
    final progressPercent = levelData['progress'];

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '레벨 $level',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3748),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getLevelDescription(level),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF718096),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$progressPercent%',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4299E1),
                  ),
                ),
                Text(
                  '총 ${totalScore}점',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF718096),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        // 진도 바
        Container(
          height: 6,
          decoration: BoxDecoration(
            color: const Color(0xFFF7FAFC),
            borderRadius: BorderRadius.circular(3),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progressPercent / 100,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4299E1), Color(0xFF9F7AEA)],
                ),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  '완료한 레슨: ${completedLessons.length}개',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF718096),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: Colors.orange.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.skip_next,
                        size: 12,
                        color: Colors.orange[700],
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${_skippedItems.length}',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.orange[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            GestureDetector(
              onTap: () => _showResetProgressDialog(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE53E3E).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFE53E3E).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.refresh,
                      size: 12,
                      color: const Color(0xFFE53E3E),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '초기화',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFE53E3E),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildLevelButtons(),
      ],
    );
  }

  Widget _buildLevelButtons() {
    final levelData = _calculateLevelProgress();
    final currentLevel = levelData['level'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '레벨별 복습',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF4A5568),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(5, (index) {
            final level = index + 1;
            final isCompleted = level < currentLevel;
            final isCurrent = level == currentLevel;
            final isLocked = level > currentLevel;

            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: index < 4 ? 6 : 0),
                child: GestureDetector(
                  onTap: isCompleted || isCurrent
                      ? () => _startLevelReview(level)
                      : null,
                  child: Container(
                    height: 32,
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? const Color(0xFF10B981).withOpacity(0.1)
                          : isCurrent
                          ? const Color(0xFF3B82F6).withOpacity(0.1)
                          : const Color(0xFFF7FAFC),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isCompleted
                            ? const Color(0xFF10B981)
                            : isCurrent
                            ? const Color(0xFF3B82F6)
                            : const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (isCompleted) ...[
                            Icon(
                              Icons.check_circle,
                              size: 12,
                              color: const Color(0xFF10B981),
                            ),
                            const SizedBox(width: 2),
                          ] else if (isCurrent) ...[
                            Icon(
                              Icons.play_circle_filled,
                              size: 12,
                              color: const Color(0xFF3B82F6),
                            ),
                            const SizedBox(width: 2),
                          ] else if (isLocked) ...[
                            Icon(
                              Icons.lock,
                              size: 12,
                              color: const Color(0xFFCBD5E0),
                            ),
                            const SizedBox(width: 2),
                          ],
                          Text(
                            '$level',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isCompleted
                                  ? const Color(0xFF10B981)
                                  : isCurrent
                                  ? const Color(0xFF3B82F6)
                                  : const Color(0xFFCBD5E0),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  void _startLevelReview(int level) {
    // 해당 레벨의 첫 번째 문자로 이동
    int startIndex = 0;
    for (int i = 1; i < level; i++) {
      startIndex += levelStructure[i]!.length;
    }

    setState(() {
      isReviewMode = true;
      reviewLevelStep = startIndex;
      isLearningMode = true; // 학습 모드도 활성화
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.school, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              '레벨 $level 복습을 시작합니다! ${learningSequence[startIndex]}부터 시작해요.',
            ),
          ],
        ),
        backgroundColor: const Color(0xFF3B82F6),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // 모든 레벨 완료 축하 다이얼로그
  void _showAllLevelsCompletedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Container(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 축하 아이콘
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.celebration,
                    size: 40,
                    color: Color(0xFF10B981),
                  ),
                ),
                const SizedBox(height: 20),

                // 축하 메시지
                const Text(
                  '🎉 축하합니다! 🎉',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3748),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                const Text(
                  '모든 레벨의 학습을\n완료하였습니다!!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4A5568),
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // 완료 통계
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '완료한 문자:',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF718096),
                            ),
                          ),
                          Text(
                            '40개 (100%)',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '완료한 레벨:',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF718096),
                            ),
                          ),
                          Text(
                            '5/5 레벨',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 복습 안내 메시지
                const Text(
                  '이제 모든 레벨을\n복습해 보실 수 있습니다!',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF4A5568),
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // 확인 버튼
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      '복습하러 가기',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDefaultProgress() {
    return Column(
      children: [
        Row(
          children: [
            const Icon(Icons.school, color: Color(0xFFCBD5E0), size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '학습을 시작해보세요!',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4A5568),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '로그인하면 진도를 확인할 수 있습니다',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _getLevelDescription(int level) {
    switch (level) {
      case 1:
        return '기초 자음 + 된소리 (ㄱ~ㅆ)';
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
                onPressed: () async {
                  // 같은 모드로 퀴즈 다시 시작
                  String currentMode = selectedQuizType;
                  setState(() {
                    showQuizResult = false;
                    currentQuestionIndex = 0;
                    correctAnswers = 0;
                    totalTimeSpent = 0;
                    isQuizStarted = false;
                    _shuffledQuizData.clear();
                  });

                  // 백엔드에서 새로운 퀴즈 문제 생성
                  await _startQuizWithBackend(currentMode);
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
                  // 퀴즈 모드 선택 화면으로 돌아가기
                  setState(() {
                    showQuizResult = false;
                    selectedQuizType = '';
                    currentQuestionIndex = 0;
                    correctAnswers = 0;
                    totalTimeSpent = 0;
                    isQuizStarted = false;
                    _shuffledQuizData.clear();
                    // 퀴즈 모드 선택 화면으로 돌아감
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
      height: 100, // 고정 높이 설정
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center, // 중앙 정렬
        children: [
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 20, // 폰트 크기 조정 (24 → 20)
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
              maxLines: 1, // 한 줄로 제한
              overflow: TextOverflow.ellipsis, // 넘치면 ... 표시
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: color.withOpacity(0.8)),
            textAlign: TextAlign.center,
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

        const SizedBox(height: 12),

        // Question card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          decoration: BoxDecoration(
            color: showCorrectAnswer && isAnswerCorrect
                ? const Color(0xFFF0FDF4)
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: showCorrectAnswer && isAnswerCorrect
                ? Border.all(color: const Color(0xFF10B981), width: 2)
                : null,
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
              // 정답 표시
              if (showCorrectAnswer && isAnswerCorrect) ...[
                Column(
                  children: [
                    const SizedBox(height: 16),
                    const Text(
                      '퀴즈 완료',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF718096),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            size: 24,
                          ),
                          SizedBox(width: 12),
                          Text(
                            '정답입니다! 🎉',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '다음 문제로 이동합니다...',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF10B981),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ] else ...[
                // 기존 퀴즈 표시
                Builder(
                  builder: (context) {
                    final currentQuestion = _getCurrentQuestion();
                    if (currentQuestion == null) {
                      return const Text(
                        '문제를 불러오는 중...',
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF718096),
                        ),
                      );
                    }

                    return Column(
                      children: [
                        Text(
                          currentQuestion['type']!,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF718096),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currentQuestion['question']!,
                          style: const TextStyle(
                            fontSize: 72,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D3748),
                          ),
                        ),
                        
                        // 자모 진행 상황 표시 (모든 퀴즈)
                        if (_currentJamoSequence != null && _currentJamoSequence!.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          _buildJamoProgressRow(),
                          const SizedBox(height: 8),
                        ] else ...[
                          const SizedBox(height: 8),
                        ],
                        
                        Text(
                          showCorrectAnswer && isAnswerCorrect
                              ? '정답을 맞혔습니다! 다음 문제로 이동합니다...'
                              : _getQuizDescription(currentQuestion),
                          style: TextStyle(
                            fontSize: 16,
                            color: showCorrectAnswer && isAnswerCorrect
                                ? const Color(0xFF10B981)
                                : const Color(0xFF4A5568),
                            fontWeight: showCorrectAnswer && isAnswerCorrect
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuizModeContent() {
    return Column(children: [_buildQuizTypeButtons()]);
  }

  Widget _buildQuizTypeButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 퀴즈 모드 선택 헤더
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6B73FF), Color(0xFF9F7AEA)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.quiz, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '퀴즈 모드 선택',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '원하는 난이도를 선택하여 수어 퀴즈에 도전해보세요',
                      style: TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 퀴즈 타입 카드들
        _buildQuizTypeCard(
          '낱말퀴즈',
          '40개 문제',
          '한국어 자음과 모음 랜덤퀴즈',
          'Tr',
          const Color(0xFF6366F1),
        ),
        const SizedBox(height: 12),
        _buildQuizTypeCard(
          '초급',
          '10개 문제',
          '받침 없는 글자 (자음 + 모음)',
          '1',
          const Color(0xFF10B981),
        ),
        const SizedBox(height: 12),
        _buildQuizTypeCard(
          '중급',
          '5개 문제',
          '받침 있는 글자 (자음 + 모음 + 받침)',
          '2',
          const Color(0xFF3B82F6),
        ),
        const SizedBox(height: 12),
        _buildQuizTypeCard(
          '고급',
          '5개 문제',
          '복합 모음이 포함된 글자',
          '3',
          const Color(0xFFEF4444),
        ),
      ],
    );
  }

  Widget _buildQuizTypeCard(
    String type,
    String problemCount,
    String description,
    String icon,
    Color color,
  ) {
    return GestureDetector(
      onTap: () async {
        // 백엔드에서 퀴즈 문제 생성
        await _startQuizWithBackend(type);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // 아이콘 부분
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  icon,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // 텍스트 부분
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        type,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D3748),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        problemCount,
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
                      fontSize: 12,
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

  Widget _buildBottomDescription() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          RichText(
            textAlign: TextAlign.center,
            text: const TextSpan(
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
                height: 1.5,
              ),
              children: [
                TextSpan(
                  text: 'SignTalk',
                  style: TextStyle(
                    color: Color(0xFF4299E1), // 파란색
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextSpan(
                  text:
                      '은 한국 수어 학습을 위한 교육 플랫폼입니다. AI를 이용한 기반 인식 시스템으로 실전 같은 학습 경험을 제공합니다.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '자유로운 학습으로 가족을 다지고, 퀴즈로 실력을 검증하며, 자유로운 연습으로 완성해보세요!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  void _showResetProgressDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('진도 초기화'),
          content: const Text(
            '학습 진도를 초기화하시겠습니까?\n'
            '모든 진도가 삭제되고 처음부터 다시 시작됩니다.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _resetProgress();
              },
              child: const Text('초기화', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _resetProgress() {
    setState(() {
      userProgress = {'level': 1, 'score': 0, 'completed_lessons': []};
      currentLearningStep = 0;
      isLearningComplete = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('진도가 초기화되었습니다'),
        backgroundColor: Colors.green,
      ),
    );
  }

  // 스킵된 항목 관리를 위한 정적 메서드
  static Set<String> _skippedItems = {};

  // 백엔드 API 연동 스킵 기능 (학습 모드용)
  void _handleSkipLearning() async {
    if (isLearningMode) {
      // 학습 모드 스킵
      String currentTarget = getCurrentLearningCharacter();
      if (currentTarget != '완료') {
        try {
          // 백엔드 스킵 API 호출
          final result = await QuizService.skipQuiz(
            'ksl',
            '학습모드',
            currentTarget,
            sessionId: _currentSessionId ?? 'learning_session',
            level: _getCurrentLevel(),
            correctAnswer: currentTarget,
            responseTime:
                (DateTime.now().millisecondsSinceEpoch - _questionStartTime)
                    .toInt(),
          );

          if (result['success'] == true) {
            print('✅ 백엔드 스킵 API 성공: ${result['message']}');
          } else {
            print('❌ 백엔드 스킵 API 실패: ${result['error']}');
          }
        } catch (e) {
          print('❌ 백엔드 스킵 API 오류: $e');
        }

        // 로컬 상태 업데이트
        setState(() {
          _skippedItems.add(currentTarget);
        });

        // 스킵 후 로컬 진도 업데이트 (다음 단계로 이동)
        _updateLocalProgressForSkip(currentTarget);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"$currentTarget"를 스킵했습니다'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }

  // 기존 스킵 기능 (퀴즈 모드용)
  void _skipCurrentProblem() {
    if (isLearningMode) {
      // 학습 모드는 _handleSkipLearning() 사용
      _handleSkipLearning();
    } else if (isQuizStarted) {
      // 퀴즈 모드 스킵 (백엔드 API 연동)
      _handleSkipQuiz();
    }
  }

  // 퀴즈 모드 스킵 처리 (백엔드 API 연동)
  void _handleSkipQuiz() async {
    final currentQuestion = _getCurrentQuestion();
    if (currentQuestion != null) {
      final skippedAnswer = currentQuestion['question'] ?? '';

      try {
        // 백엔드 스킵 API 호출
        final result = await QuizService.skipQuiz(
          'ksl',
          _currentQuizMode ?? '낱말퀴즈',
          skippedAnswer,
          sessionId: _currentSessionId ?? 'quiz_session',
          level: _getCurrentLevel(),
          correctAnswer: skippedAnswer,
          responseTime:
              (DateTime.now().millisecondsSinceEpoch - _questionStartTime)
                  .toInt(),
        );

        if (result['success'] == true) {
          print('✅ 퀴즈 스킵 API 성공: ${result['message']}');
        } else {
          print('❌ 퀴즈 스킵 API 실패: ${result['error']}');
        }
      } catch (e) {
        print('❌ 퀴즈 스킵 API 오류: $e');
      }

      // 로컬 상태 업데이스트
      setState(() {
        _skippedItems.add(skippedAnswer);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"$skippedAnswer" 문제를 스킵했습니다'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 1),
        ),
      );

      _nextQuestion();
    }
  }

  // 백엔드 연결 실패 시 폴백 문제 생성
  List<Map<String, String>> _generateFallbackQuestions(String type) {
    switch (type) {
      case '초급':
        return [
          {'type': type, 'question': '가', 'description': '위 글자를 수어로 표현해주세요'},
          {'type': type, 'question': '나', 'description': '위 글자를 수어로 표현해주세요'},
          {'type': type, 'question': '다', 'description': '위 글자를 수어로 표현해주세요'},
          {'type': type, 'question': '라', 'description': '위 글자를 수어로 표현해주세요'},
          {'type': type, 'question': '마', 'description': '위 글자를 수어로 표현해주세요'},
          {'type': type, 'question': '바', 'description': '위 글자를 수어로 표현해주세요'},
          {'type': type, 'question': '사', 'description': '위 글자를 수어로 표현해주세요'},
          {'type': type, 'question': '아', 'description': '위 글자를 수어로 표현해주세요'},
          {'type': type, 'question': '자', 'description': '위 글자를 수어로 표현해주세요'},
          {'type': type, 'question': '차', 'description': '위 글자를 수어로 표현해주세요'},
        ];
      case '중급':
        return [
          {'type': type, 'question': '각', 'description': '위 글자를 수어로 표현해주세요'},
          {'type': type, 'question': '밥', 'description': '위 글자를 수어로 표현해주세요'},
          {'type': type, 'question': '집', 'description': '위 글자를 수어로 표현해주세요'},
          {'type': type, 'question': '물', 'description': '위 글자를 수어로 표현해주세요'},
          {'type': type, 'question': '책', 'description': '위 글자를 수어로 표현해주세요'},
        ];
      case '고급':
        return [
          {'type': type, 'question': '학교', 'description': '위 단어를 수어로 표현해주세요'},
          {'type': type, 'question': '가족', 'description': '위 단어를 수어로 표현해주세요'},
          {'type': type, 'question': '친구', 'description': '위 단어를 수어로 표현해주세요'},
          {'type': type, 'question': '선생님', 'description': '위 단어를 수어로 표현해주세요'},
          {'type': type, 'question': '공부', 'description': '위 단어를 수어로 표현해주세요'},
        ];
      default:
        return [
          {'type': type, 'question': 'ㄱ', 'description': '위 문자를 수어로 표현해주세요'},
          {'type': type, 'question': 'ㄴ', 'description': '위 문자를 수어로 표현해주세요'},
          {'type': type, 'question': 'ㄷ', 'description': '위 문자를 수어로 표현해주세요'},
          {'type': type, 'question': 'ㅏ', 'description': '위 문자를 수어로 표현해주세요'},
          {'type': type, 'question': 'ㅓ', 'description': '위 문자를 수어로 표현해주세요'},
        ];
    }
  }

  // 백엔드 API로 퀴즈 시작
  Future<void> _startQuizWithBackend(String type) async {
    try {
      print('🎯 백엔드 퀴즈 시작: $type');
      print('🔍 현재 _shuffledQuizData 상태: ${_shuffledQuizData.length}개');

      // 1. 퀴즈 세션 시작
      print('📡 1단계: 퀴즈 세션 시작 요청...');
      final sessionResult = await QuizService.startQuizSession(
        language: 'ksl',
        quizType: type,
      );
      print('📡 세션 결과: $sessionResult');

      if (sessionResult['success'] != true) {
        throw Exception('퀴즈 세션 시작 실패: ${sessionResult['error']}');
      }

      // 2. 백엔드에서 퀴즈 문제 생성
      print('📡 2단계: 퀴즈 문제 생성 요청...');
      final quizResult = await QuizService.generateQuizByMode(
        language: 'ksl',
        mode: type,
      );
      print('📡 퀴즈 생성 결과: $quizResult');

      if (quizResult['success'] != true) {
        throw Exception('퀴즈 문제 생성 실패: ${quizResult['error']}');
      }

      // 3. 백엔드 데이터로 퀴즈 시작
      final problems = quizResult['problems'] as List<dynamic>? ?? [];
      final convertedProblems = QuizService.convertProblemsToAppFormat(
        problems,
        type,
      );

      print('🔍 백엔드 응답 데이터:');
      print('  - 원본 problems: ${problems.length}개');
      print('  - 변환된 problems: ${convertedProblems.length}개');
      if (convertedProblems.isNotEmpty) {
        print('  - 첫 번째 문제: ${convertedProblems[0]}');
      }

      setState(() {
        selectedQuizType = type;
        isQuizStarted = true;
        currentQuestionIndex = 0;
        correctAnswers = 0;
        timeRemaining = 25;
        totalTimeSpent = 0;
        quizStartTime = DateTime.now();

        // 백엔드 API 연동 설정
        _currentQuizMode = type;
        _currentSessionId = sessionResult['session_id'];
        _questionStartTime = DateTime.now().millisecondsSinceEpoch;

        // 백엔드에서 받은 문제 데이터 사용
        _shuffledQuizData = convertedProblems;
      });

      _startTimer();

      print('✅ 백엔드 퀴즈 시작 성공: ${problems.length}개 문제');

      // 첫 번째 문제의 자모 분해 백그라운드 처리
      if (_shuffledQuizData.isNotEmpty) {
        _prepareJamoSequence();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('백엔드에서 ${problems.length}개 문제를 불러왔습니다'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('❌ 백엔드 퀴즈 시작 실패: $e');

      // 백엔드 실패 시 로컬 데이터로 폴백
      setState(() {
        selectedQuizType = type;
        isQuizStarted = true;
        currentQuestionIndex = 0;
        correctAnswers = 0;
        timeRemaining = 25;
        totalTimeSpent = 0;
        quizStartTime = DateTime.now();

        // 로컬 폴백 설정
        _currentQuizMode = type;
        _currentSessionId =
            'local_quiz_${DateTime.now().millisecondsSinceEpoch}';
        _questionStartTime = DateTime.now().millisecondsSinceEpoch;

        // 로컬 데이터 사용 (모든 모드 지원)
        if (quizData.containsKey(type)) {
          _shuffledQuizData = List.from(quizData[type] ?? []);
          _shuffledQuizData.shuffle();
        } else {
          // 백엔드 전용 모드인 경우 기본 문제 생성
          _shuffledQuizData = _generateFallbackQuestions(type);
        }
      });

      _startTimer();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('백엔드 연결 실패, 로컬 데이터로 퀴즈를 시작합니다'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // ==== 자모 분해 백그라운드 처리 함수들 ====

  /// 현재 문제의 자모 순서 준비
  Future<void> _prepareJamoSequence() async {
    final currentQuestion = _getCurrentQuestion();
    if (currentQuestion == null) return;

    final word = currentQuestion['question'] ?? '';
    print('🔤 자모 분해 준비: "$word"');

    try {
      final jamoSequence = await JamoService.decomposeWord(word);
      setState(() {
        _currentJamoSequence = jamoSequence;
        _currentJamoIndex = 0;
      });

      if (jamoSequence != null) {
        print('✅ 자모 순서 준비 완료: $word → $jamoSequence');
        print('   현재 기대 자모: ${jamoSequence[0]}');
      }
    } catch (e) {
      print('❌ 자모 분해 실패: $e');
      setState(() {
        _currentJamoSequence = null;
        _currentJamoIndex = 0;
      });
    }
  }

  /// 수어 인식 결과와 자모 순서 비교
  bool _checkJamoSequence(String recognizedJamo) {
    if (_currentJamoSequence == null || _currentJamoSequence!.isEmpty) {
      return false; // 자모 분해가 안된 경우 기존 방식으로
    }

    if (_currentJamoIndex >= _currentJamoSequence!.length) {
      return true; // 이미 모든 자모 완성
    }

    final expectedJamo = _currentJamoSequence![_currentJamoIndex];
    print('🔍 자모 비교: 인식="$recognizedJamo" vs 기대="$expectedJamo"');

    if (recognizedJamo == expectedJamo) {
      setState(() {
        _currentJamoIndex++;
      });

      print('✅ 자모 일치! 진행률: $_currentJamoIndex/${_currentJamoSequence!.length}');

      // 모든 자모 완성 확인
      if (_currentJamoIndex >= _currentJamoSequence!.length) {
        print('🎉 단어 완성! 다음 문제로 이동');
        return true; // 단어 완성
      } else {
        // 다음 자모 안내
        final nextJamo = _currentJamoSequence![_currentJamoIndex];
        print('➡️ 다음 자모: $nextJamo');
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('정답! 다음: "$nextJamo" 수어를 표현해주세요'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1),
          ),
        );
        return false; // 아직 진행 중
      }
    } else {
      print('❌ 자모 불일치');
      return false;
    }
  }

  /// 다음 문제로 이동 시 자모 순서 리셋
  void _resetJamoSequence() {
    setState(() {
      _currentJamoSequence = null;
      _currentJamoIndex = 0;
    });
  }

  /// 자모 진행 상황 표시 (여러 줄 지원)
  Widget _buildJamoProgressRow() {
    if (_currentJamoSequence == null || _currentJamoSequence!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8.0, // 가로 간격
      runSpacing: 8.0, // 세로 간격 (줄바꿈 시)
      children: List.generate(_currentJamoSequence!.length, (index) {
        final isCompleted = index < _currentJamoIndex;
        final isCurrent = index == _currentJamoIndex;
        
        Color backgroundColor;
        Color textColor;
        String displayText = _currentJamoSequence![index];
        
        if (isCompleted) {
          backgroundColor = const Color(0xFF4299E1); // 파란색 (완료)
          textColor = Colors.white;
        } else if (isCurrent) {
          backgroundColor = const Color(0xFF4299E1); // 파란색 (현재)
          textColor = Colors.white;
        } else {
          backgroundColor = const Color(0xFFE2E8F0); // 회색 (대기)
          textColor = const Color(0xFF718096);
        }
        
        return Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              displayText,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ),
        );
      }),
    );
  }

  /// 퀴즈 설명 텍스트 가져오기
  String _getQuizDescription(Map<String, String> currentQuestion) {
    // 자모 분해 모드인 경우 현재 기대하는 자모 표시
    if (_currentJamoSequence != null && 
        _currentJamoIndex < _currentJamoSequence!.length) {
      final currentJamo = _currentJamoSequence![_currentJamoIndex];
      return '$currentJamo 수어를 표현해주세요';
    }
    
    // 기존 방식
    return currentQuestion['description']!;
  }
}
