# -*- coding: utf-8 -*-
"""
한글 자모 분해/조합 API
- 한글 문자를 초성/중성/종성으로 분해
- 수어 학습을 위한 자모 순서 제공
"""

from flask import Blueprint, jsonify, request

jamo_decompose_bp = Blueprint('jamo_decompose', __name__)

# ==== 한글 자모 테이블 ====
# 유니코드 한글: 0xAC00(가) ~ 0xD7A3(힣)
# 계산식: ((초성 × 21) + 중성) × 28 + 종성 + 0xAC00

CHOSUNG_LIST = [
    'ㄱ', 'ㄲ', 'ㄴ', 'ㄷ', 'ㄸ', 'ㄹ', 'ㅁ', 'ㅂ', 'ㅃ', 'ㅅ',
    'ㅆ', 'ㅇ', 'ㅈ', 'ㅉ', 'ㅊ', 'ㅋ', 'ㅌ', 'ㅍ', 'ㅎ'
]

JUNGSUNG_LIST = [
    'ㅏ', 'ㅐ', 'ㅑ', 'ㅒ', 'ㅓ', 'ㅔ', 'ㅕ', 'ㅖ', 'ㅗ', 'ㅘ',
    'ㅙ', 'ㅚ', 'ㅛ', 'ㅜ', 'ㅝ', 'ㅞ', 'ㅟ', 'ㅠ', 'ㅡ', 'ㅢ', 'ㅣ'
]

JONGSUNG_LIST = [
    '', 'ㄱ', 'ㄲ', 'ㄳ', 'ㄴ', 'ㄵ', 'ㄶ', 'ㄷ', 'ㄹ', 'ㄺ',
    'ㄻ', 'ㄼ', 'ㄽ', 'ㄾ', 'ㄿ', 'ㅀ', 'ㅁ', 'ㅂ', 'ㅄ', 'ㅅ',
    'ㅆ', 'ㅇ', 'ㅈ', 'ㅊ', 'ㅋ', 'ㅌ', 'ㅍ', 'ㅎ'
]

# 복합 자모 분해 (수어는 기본 자모만 사용)
COMPLEX_JONGSUNG_MAP = {
    'ㄳ': ['ㄱ', 'ㅅ'],
    'ㄵ': ['ㄴ', 'ㅈ'],
    'ㄶ': ['ㄴ', 'ㅎ'],
    'ㄺ': ['ㄹ', 'ㄱ'],
    'ㄻ': ['ㄹ', 'ㅁ'],
    'ㄼ': ['ㄹ', 'ㅂ'],
    'ㄽ': ['ㄹ', 'ㅅ'],
    'ㄾ': ['ㄹ', 'ㅌ'],
    'ㄿ': ['ㄹ', 'ㅍ'],
    'ㅀ': ['ㄹ', 'ㅎ'],
    'ㅄ': ['ㅂ', 'ㅅ']
}

COMPLEX_JUNGSUNG_MAP = {
    'ㅘ': ['ㅗ', 'ㅏ'],
    'ㅙ': ['ㅗ', 'ㅐ'],
    'ㅚ': ['ㅗ', 'ㅣ'],
    'ㅝ': ['ㅜ', 'ㅓ'],
    'ㅞ': ['ㅜ', 'ㅔ'],
    'ㅟ': ['ㅜ', 'ㅣ'],
    'ㅢ': ['ㅡ', 'ㅣ']
}


def is_hangul(char):
    """한글 음절인지 확인"""
    return 0xAC00 <= ord(char) <= 0xD7A3


def is_jamo(char):
    """자음/모음인지 확인"""
    # 초성 자음
    if char in CHOSUNG_LIST:
        return True
    # 중성 모음
    if char in JUNGSUNG_LIST:
        return True
    # 종성 자음
    if char in JONGSUNG_LIST:
        return True
    return False


def decompose_hangul(char):
    """
    한글 음절을 초성/중성/종성으로 분해
    
    Args:
        char: 한글 음절 (예: '안')
    
    Returns:
        dict: {'chosung': 'ㅇ', 'jungsung': 'ㅏ', 'jongsung': 'ㄴ'}
    """
    if not is_hangul(char):
        return None
    
    code = ord(char) - 0xAC00
    
    jongsung_index = code % 28
    jungsung_index = ((code - jongsung_index) // 28) % 21
    chosung_index = ((code - jongsung_index) // 28) // 21
    
    return {
        'chosung': CHOSUNG_LIST[chosung_index],
        'jungsung': JUNGSUNG_LIST[jungsung_index],
        'jongsung': JONGSUNG_LIST[jongsung_index]
    }


def decompose_to_jamo_list(char, include_complex=False):
    """
    한글 음절을 자모 리스트로 분해 (수어 학습용)
    
    Args:
        char: 한글 음절 (예: '안')
        include_complex: 복합 자모 분해 여부
    
    Returns:
        list: ['ㅇ', 'ㅏ', 'ㄴ']
    """
    if is_jamo(char):
        # 이미 자모인 경우
        return [char]
    
    if not is_hangul(char):
        # 한글이 아닌 경우
        return [char]
    
    decomposed = decompose_hangul(char)
    jamo_list = []
    
    # 초성
    chosung = decomposed['chosung']
    jamo_list.append(chosung)
    
    # 중성
    jungsung = decomposed['jungsung']
    if include_complex and jungsung in COMPLEX_JUNGSUNG_MAP:
        jamo_list.extend(COMPLEX_JUNGSUNG_MAP[jungsung])
    else:
        jamo_list.append(jungsung)
    
    # 종성
    jongsung = decomposed['jongsung']
    if jongsung:  # 종성이 있는 경우만
        if include_complex and jongsung in COMPLEX_JONGSUNG_MAP:
            jamo_list.extend(COMPLEX_JONGSUNG_MAP[jongsung])
        else:
            jamo_list.append(jongsung)
    
    return jamo_list


def decompose_string(text, include_complex=False):
    """
    문자열 전체를 자모로 분해
    
    Args:
        text: 한글 문자열 (예: '안녕')
        include_complex: 복합 자모 분해 여부
    
    Returns:
        list: ['ㅇ', 'ㅏ', 'ㄴ', 'ㄴ', 'ㅕ', 'ㅇ']
    """
    result = []
    for char in text:
        result.extend(decompose_to_jamo_list(char, include_complex))
    return result


# ==== API 엔드포인트 ====

@jamo_decompose_bp.route('/api/jamo/decompose', methods=['POST'])
def decompose_text():
    """
    한글 문자열을 자모로 분해
    
    Request:
        {
            "text": "안녕하세요",
            "include_complex": false  // 복합 자모 분해 여부 (선택)
        }
    
    Response:
        {
            "original": "안녕하세요",
            "jamo_list": ["ㅇ", "ㅏ", "ㄴ", "ㄴ", "ㅕ", "ㅇ", ...],
            "jamo_count": 15,
            "char_details": [
                {
                    "char": "안",
                    "jamo": ["ㅇ", "ㅏ", "ㄴ"],
                    "decomposed": {
                        "chosung": "ㅇ",
                        "jungsung": "ㅏ",
                        "jongsung": "ㄴ"
                    }
                },
                ...
            ]
        }
    """
    try:
        data = request.get_json()
        
        if not data or 'text' not in data:
            return jsonify({'error': 'text 필드가 필요합니다.'}), 400
        
        text = data['text']
        include_complex = data.get('include_complex', False)
        
        if not text:
            return jsonify({'error': '빈 문자열은 처리할 수 없습니다.'}), 400
        
        # 전체 자모 리스트
        jamo_list = decompose_string(text, include_complex)
        
        # 각 글자별 상세 정보
        char_details = []
        for char in text:
            if is_hangul(char):
                detail = {
                    'char': char,
                    'jamo': decompose_to_jamo_list(char, include_complex),
                    'decomposed': decompose_hangul(char),
                    'is_hangul': True
                }
            elif is_jamo(char):
                detail = {
                    'char': char,
                    'jamo': [char],
                    'is_jamo': True
                }
            else:
                detail = {
                    'char': char,
                    'jamo': [char],
                    'is_other': True
                }
            char_details.append(detail)
        
        return jsonify({
            'success': True,
            'original': text,
            'jamo_list': jamo_list,
            'jamo_count': len(jamo_list),
            'char_count': len(text),
            'char_details': char_details,
            'include_complex': include_complex
        }), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@jamo_decompose_bp.route('/api/jamo/decompose/<text>', methods=['GET'])
def decompose_text_get(text):
    """
    GET 방식 자모 분해 (간단한 사용)
    
    Example:
        GET /api/jamo/decompose/안녕
    
    Response:
        {
            "original": "안녕",
            "jamo_list": ["ㅇ", "ㅏ", "ㄴ", "ㄴ", "ㅕ", "ㅇ"]
        }
    """
    try:
        include_complex = request.args.get('complex', 'false').lower() == 'true'
        jamo_list = decompose_string(text, include_complex)
        
        return jsonify({
            'success': True,
            'original': text,
            'jamo_list': jamo_list,
            'jamo_count': len(jamo_list)
        }), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@jamo_decompose_bp.route('/api/jamo/validate', methods=['POST'])
def validate_jamo():
    """
    자모가 올바른지 검증
    
    Request:
        {
            "jamo": "ㄱ"
        }
    
    Response:
        {
            "jamo": "ㄱ",
            "is_valid": true,
            "type": "chosung",  // chosung, jungsung, jongsung
            "can_be_learned": true  // 수어로 학습 가능한지
        }
    """
    try:
        data = request.get_json()
        
        if not data or 'jamo' not in data:
            return jsonify({'error': 'jamo 필드가 필요합니다.'}), 400
        
        jamo = data['jamo']
        
        if len(jamo) != 1:
            return jsonify({'error': '단일 자모만 검증 가능합니다.'}), 400
        
        jamo_type = None
        is_valid = False
        
        if jamo in CHOSUNG_LIST:
            jamo_type = 'chosung'
            is_valid = True
        elif jamo in JUNGSUNG_LIST:
            jamo_type = 'jungsung'
            is_valid = True
        elif jamo in JONGSUNG_LIST and jamo != '':
            jamo_type = 'jongsung'
            is_valid = True
        
        # 복합 자모 확인
        is_complex = (jamo in COMPLEX_JONGSUNG_MAP or 
                     jamo in COMPLEX_JUNGSUNG_MAP)
        
        return jsonify({
            'success': True,
            'jamo': jamo,
            'is_valid': is_valid,
            'type': jamo_type,
            'is_complex': is_complex,
            'can_be_learned': is_valid  # 모든 유효한 자모는 학습 가능
        }), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@jamo_decompose_bp.route('/api/jamo/info', methods=['GET'])
def get_jamo_info():
    """
    자모 시스템 정보 반환
    
    Response:
        {
            "chosung_list": ["ㄱ", "ㄲ", ...],
            "jungsung_list": ["ㅏ", "ㅐ", ...],
            "jongsung_list": ["", "ㄱ", ...],
            "total_count": 68
        }
    """
    return jsonify({
        'success': True,
        'chosung_list': CHOSUNG_LIST,
        'chosung_count': len(CHOSUNG_LIST),
        'jungsung_list': JUNGSUNG_LIST,
        'jungsung_count': len(JUNGSUNG_LIST),
        'jongsung_list': [j for j in JONGSUNG_LIST if j],  # 빈 문자열 제외
        'jongsung_count': len(JONGSUNG_LIST) - 1,
        'total_jamo_count': len(CHOSUNG_LIST) + len(JUNGSUNG_LIST) + len(JONGSUNG_LIST) - 1,
        'complex_jongsung': list(COMPLEX_JONGSUNG_MAP.keys()),
        'complex_jungsung': list(COMPLEX_JUNGSUNG_MAP.keys())
    }), 200
