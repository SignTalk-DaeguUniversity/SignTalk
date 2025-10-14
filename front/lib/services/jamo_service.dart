import 'dart:convert';
import 'package:http/http.dart' as http;

class JamoService {
  // 다중 서버 URL 지원
  static const List<String> _baseUrls = [
    'http://10.0.2.2:5002',  // Android 에뮬레이터
    'http://192.168.45.98:5002',  // WiFi 연결
    'http://127.0.0.1:5002',  // 로컬호스트
    'http://localhost:5002',  // 백업
  ];

  /// 한글 문자열을 자모로 분해 (백그라운드용)
  static Future<List<String>?> decomposeWord(String word) async {
    for (String baseUrl in _baseUrls) {
      try {
        print('🔤 자모 분해 API 호출: $baseUrl/api/jamo/decompose');
        print('   - 단어: "$word"');

        final response = await http.post(
          Uri.parse('$baseUrl/api/jamo/decompose'),
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'text': word,
            'include_complex': false,
          }),
        ).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          
          if (data['success'] == true) {
            final jamoList = List<String>.from(data['jamo_list']);
            print('✅ 자모 분해 성공: $word → $jamoList');
            return jamoList;
          }
        }
      } catch (e) {
        print('❌ 자모 분해 API 연결 실패 ($baseUrl): $e');
        continue;
      }
    }

    // 모든 서버 연결 실패 시 로컬 폴백
    print('⚠️ 자모 분해 API 실패, 로컬 분해 시도');
    return _localDecompose(word);
  }

  /// 로컬 자모 분해 (백엔드 연결 실패 시)
  static List<String>? _localDecompose(String word) {
    if (word.isEmpty) return null;
    
    List<String> result = [];
    for (int i = 0; i < word.length; i++) {
      String char = word[i];
      if (_isHangul(char)) {
        result.addAll(_simpleDecompose(char));
      } else {
        result.add(char);
      }
    }
    
    return result.isNotEmpty ? result : null;
  }

  /// 한글 음절 확인
  static bool _isHangul(String char) {
    int code = char.codeUnitAt(0);
    return code >= 0xAC00 && code <= 0xD7A3;
  }

  /// 간단한 로컬 분해
  static List<String> _simpleDecompose(String char) {
    if (!_isHangul(char)) return [char];
    
    int code = char.codeUnitAt(0) - 0xAC00;
    
    int jongsung = code % 28;
    int jungsung = ((code - jongsung) / 28).floor() % 21;
    int chosung = ((code - jongsung) / 28 / 21).floor();
    
    const chosungList = ['ㄱ', 'ㄲ', 'ㄴ', 'ㄷ', 'ㄸ', 'ㄹ', 'ㅁ', 'ㅂ', 'ㅃ', 'ㅅ', 'ㅆ', 'ㅇ', 'ㅈ', 'ㅉ', 'ㅊ', 'ㅋ', 'ㅌ', 'ㅍ', 'ㅎ'];
    const jungsungList = ['ㅏ', 'ㅐ', 'ㅑ', 'ㅒ', 'ㅓ', 'ㅔ', 'ㅕ', 'ㅖ', 'ㅗ', 'ㅘ', 'ㅙ', 'ㅚ', 'ㅛ', 'ㅜ', 'ㅝ', 'ㅞ', 'ㅟ', 'ㅠ', 'ㅡ', 'ㅢ', 'ㅣ'];
    const jongsungList = ['', 'ㄱ', 'ㄲ', 'ㄳ', 'ㄴ', 'ㄵ', 'ㄶ', 'ㄷ', 'ㄹ', 'ㄺ', 'ㄻ', 'ㄼ', 'ㄽ', 'ㄾ', 'ㄿ', 'ㅀ', 'ㅁ', 'ㅂ', 'ㅄ', 'ㅅ', 'ㅆ', 'ㅇ', 'ㅈ', 'ㅊ', 'ㅋ', 'ㅌ', 'ㅍ', 'ㅎ'];
    
    List<String> result = [];
    result.add(chosungList[chosung]);
    result.add(jungsungList[jungsung]);
    if (jongsung > 0) {
      result.add(jongsungList[jongsung]);
    }
    
    return result;
  }
}
