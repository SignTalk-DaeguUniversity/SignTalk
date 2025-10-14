# -*- coding: utf-8 -*-
"""
한글 자모 조합 (Jamo Composition)
- 자모 리스트를 한글 문자로 조합
- 예: ['ㄱ', 'ㅏ', 'ㄴ', 'ㅣ'] -> "가니"
"""

from flask import Blueprint, jsonify, request

jamo_compose_bp = Blueprint('jamo_compose', __name__)

# 한글 자모 리스트 정의
CHOSEONG_LIST = ['ㄱ', 'ㄲ', 'ㄴ', 'ㄷ', 'ㄸ', 'ㄹ', 'ㅁ', 'ㅂ', 'ㅃ', 'ㅅ', 'ㅆ', 'ㅇ', 'ㅈ', 'ㅉ', 'ㅊ', 'ㅋ', 'ㅌ', 'ㅍ', 'ㅎ']
JUNGSEONG_LIST = ['ㅏ', 'ㅐ', 'ㅑ', 'ㅒ', 'ㅓ', 'ㅔ', 'ㅕ', 'ㅖ', 'ㅗ', 'ㅘ', 'ㅙ', 'ㅚ', 'ㅛ', 'ㅜ', 'ㅝ', 'ㅞ', 'ㅟ', 'ㅠ', 'ㅡ', 'ㅢ', 'ㅣ']
JONGSEONG_LIST = ['', 'ㄱ', 'ㄲ', 'ㄳ', 'ㄴ', 'ㄵ', 'ㄶ', 'ㄷ', 'ㄹ', 'ㄺ', 'ㄻ', 'ㄼ', 'ㄽ', 'ㄾ', 'ㄿ', 'ㅀ', 'ㅁ', 'ㅂ', 'ㅄ', 'ㅅ', 'ㅆ', 'ㅇ', 'ㅈ', 'ㅊ', 'ㅋ', 'ㅌ', 'ㅍ', 'ㅎ']

# 유니코드 한글 시작점 및 자모 개수
SBASE = 0xAC00  # 한글 음절 시작 유니코드 '가'
N_JUNGSEONG = 21  # 중성 개수
N_JONGSEONG = 28  # 종성 개수 (종성 없음 포함)


def _is_choseong(char):
    """주어진 문자가 초성인지 확인"""
    return char in CHOSEONG_LIST


def _is_jungseong(char):
    """주어진 문자가 중성인지 확인"""
    return char in JUNGSEONG_LIST


def _is_jongseong(char):
    """주어진 문자가 종성으로 사용될 수 있는지 확인 (종성 없음 제외)"""
    return char in JONGSEONG_LIST and JONGSEONG_LIST.index(char) != 0


def _compose_syllable(l, v, t=None):
    """초성, 중성, (선택적) 종성을 받아 한글 한 글자로 조합"""
    if not (_is_choseong(l) and _is_jungseong(v)):
        parts = [part for part in [l, v, t] if part]
        return "".join(parts)

    l_idx = CHOSEONG_LIST.index(l)
    v_idx = JUNGSEONG_LIST.index(v)
    t_idx = 0  # 기본값은 종성 없음
    if t and t in JONGSEONG_LIST:
        t_idx = JONGSEONG_LIST.index(t)

    syllable_code = SBASE + (l_idx * N_JUNGSEONG + v_idx) * N_JONGSEONG + t_idx
    return chr(syllable_code)


def combine_hangul_jamo(jamo_sequence):
    """
    한글 자모음 시퀀스를 입력받아 완성된 한글 문자열로 조합
    
    Args:
        jamo_sequence: 자모 리스트 (예: ['ㄱ', 'ㅏ', 'ㄴ', 'ㅣ'])
    
    Returns:
        str: 조합된 한글 문자열 (예: "가니")
    """
    result = []
    syllable_buffer = []

    for i, current_jamo in enumerate(jamo_sequence):
        if not syllable_buffer:
            if _is_choseong(current_jamo):
                syllable_buffer.append(current_jamo)
            else:
                result.append(current_jamo)
            continue

        if len(syllable_buffer) == 1:
            l = syllable_buffer[0]
            if _is_jungseong(current_jamo):
                syllable_buffer.append(current_jamo)
            else:
                result.append(l)
                syllable_buffer = []
                if _is_choseong(current_jamo):
                    syllable_buffer.append(current_jamo)
                else:
                    result.append(current_jamo)
            continue

        if len(syllable_buffer) == 2:
            l, v = syllable_buffer[0], syllable_buffer[1]

            next_jamo_is_vowel = False
            if (i + 1) < len(jamo_sequence):
                if _is_jungseong(jamo_sequence[i + 1]):
                    next_jamo_is_vowel = True

            if _is_jongseong(current_jamo) and not next_jamo_is_vowel:
                syllable_buffer.append(current_jamo)
                result.append(_compose_syllable(syllable_buffer[0], syllable_buffer[1], syllable_buffer[2]))
                syllable_buffer = []
            elif _is_choseong(current_jamo) and next_jamo_is_vowel:
                result.append(_compose_syllable(l, v))
                syllable_buffer = [current_jamo]
            elif _is_choseong(current_jamo) and not next_jamo_is_vowel:
                if _is_jongseong(current_jamo):
                    syllable_buffer.append(current_jamo)
                    result.append(_compose_syllable(syllable_buffer[0], syllable_buffer[1], syllable_buffer[2]))
                    syllable_buffer = []
                else:
                    result.append(_compose_syllable(l, v))
                    syllable_buffer = [current_jamo]
            elif _is_jungseong(current_jamo):
                result.append(_compose_syllable(l, v))
                syllable_buffer = []
                result.append(current_jamo)
            else:
                result.append(_compose_syllable(l, v))
                syllable_buffer = []
                result.append(current_jamo)
            continue

    if syllable_buffer:
        if len(syllable_buffer) == 1:
            result.append(syllable_buffer[0])
        elif len(syllable_buffer) == 2:
            result.append(_compose_syllable(syllable_buffer[0], syllable_buffer[1]))
        elif len(syllable_buffer) == 3:
            result.append(_compose_syllable(syllable_buffer[0], syllable_buffer[1], syllable_buffer[2]))

    return "".join(result)


# ==== API 엔드포인트 ====

@jamo_compose_bp.route('/api/jamo/compose', methods=['POST'])
def compose_jamo():
    """
    자모 리스트를 한글로 조합
    
    Request:
        {
            "jamo_list": ["ㅇ", "ㅏ", "ㄴ", "ㄴ", "ㅕ", "ㅇ"]
        }
    
    Response:
        {
            "success": true,
            "jamo_list": ["ㅇ", "ㅏ", "ㄴ", "ㄴ", "ㅕ", "ㅇ"],
            "composed_text": "안녕",
            "jamo_count": 6
        }
    """
    try:
        data = request.get_json()
        
        if not data or 'jamo_list' not in data:
            return jsonify({'error': 'jamo_list 필드가 필요합니다.'}), 400
        
        jamo_list = data['jamo_list']
        
        if not isinstance(jamo_list, list):
            return jsonify({'error': 'jamo_list는 배열이어야 합니다.'}), 400
        
        if not jamo_list:
            return jsonify({'error': '빈 배열은 처리할 수 없습니다.'}), 400
        
        # 자모 조합
        composed_text = combine_hangul_jamo(jamo_list)
        
        return jsonify({
            'success': True,
            'jamo_list': jamo_list,
            'composed_text': composed_text,
            'jamo_count': len(jamo_list),
            'char_count': len(composed_text)
        }), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@jamo_compose_bp.route('/api/jamo/compose/test', methods=['GET'])
def test_compose():
    """
    자모 조합 테스트 엔드포인트
    
    Response:
        여러 테스트 케이스의 조합 결과
    """
    test_cases = [
        ['ㄱ', 'ㅏ', 'ㄴ', 'ㅣ'],
        ['ㅎ', 'ㅏ', 'ㄴ', 'ㄱ', 'ㅡ', 'ㄹ'],
        ['ㅇ', 'ㅏ', 'ㄴ', 'ㄴ', 'ㅕ', 'ㅇ'],
        ['ㄱ', 'ㅏ', 'ㅁ', 'ㅅ', 'ㅏ', 'ㅎ', 'ㅏ', 'ㅁ', 'ㄴ', 'ㅣ', 'ㄷ', 'ㅏ']
    ]
    
    results = []
    for jamo_list in test_cases:
        composed = combine_hangul_jamo(jamo_list)
        results.append({
            'jamo_list': jamo_list,
            'composed_text': composed
        })
    
    return jsonify({
        'success': True,
        'test_results': results
    }), 200
