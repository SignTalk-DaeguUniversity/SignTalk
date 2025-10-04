# api/quiz.py
import random
import traceback
from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from auth.models import db, Quiz, LearningSession, Progress
from datetime import datetime
from sqlalchemy import func, case, desc

quiz_bp = Blueprint('quiz', __name__)

# 퀴즈 모드별 문제 구성
QUIZ_PROBLEMS = {
    '낱말퀴즈': {
        'description': '자음과 모음 개별 문자',
        'total_problems': 40,
        'characters': [
            # 자음 19개
            'ㄱ', 'ㄲ', 'ㄴ', 'ㄷ', 'ㄸ', 'ㄹ', 'ㅁ', 'ㅂ', 'ㅃ', 'ㅅ', 'ㅆ', 'ㅇ', 'ㅈ', 'ㅉ', 'ㅊ', 'ㅋ', 'ㅌ', 'ㅍ', 'ㅎ',
            # 모음 21개
            'ㅏ', 'ㅑ', 'ㅓ', 'ㅕ', 'ㅗ', 'ㅛ', 'ㅜ', 'ㅠ', 'ㅡ', 'ㅣ', 'ㅐ', 'ㅒ', 'ㅔ', 'ㅖ', 'ㅘ', 'ㅙ', 'ㅚ', 'ㅝ', 'ㅞ', 'ㅟ', 'ㅢ'
        ]
    },
    '초급': {
        'description': '받침 없는 한 글자 (자음+모음)',
        'total_problems': 10,
        'consonants': ['ㄱ', 'ㄲ', 'ㄴ', 'ㄷ', 'ㄸ', 'ㄹ', 'ㅁ', 'ㅂ', 'ㅃ', 'ㅅ', 'ㅆ', 'ㅇ', 'ㅈ', 'ㅉ', 'ㅊ', 'ㅋ', 'ㅌ', 'ㅍ', 'ㅎ'],
        'vowels': ['ㅏ', 'ㅑ', 'ㅓ', 'ㅕ', 'ㅗ', 'ㅛ', 'ㅜ', 'ㅠ', 'ㅡ', 'ㅣ', 'ㅐ', 'ㅒ', 'ㅔ', 'ㅖ', 'ㅘ', 'ㅙ', 'ㅚ', 'ㅝ', 'ㅞ', 'ㅟ', 'ㅢ']
    },
    '중급': {
        'description': '받침 있는 한 글자 (자음+모음+받침)',
        'total_problems': 5,
        'consonants': ['ㄱ', 'ㄲ', 'ㄴ', 'ㄷ', 'ㄸ', 'ㄹ', 'ㅁ', 'ㅂ', 'ㅃ', 'ㅅ', 'ㅆ', 'ㅇ', 'ㅈ', 'ㅉ', 'ㅊ', 'ㅋ', 'ㅌ', 'ㅍ', 'ㅎ'],
        'vowels': ['ㅏ', 'ㅑ', 'ㅓ', 'ㅕ', 'ㅗ', 'ㅛ', 'ㅜ', 'ㅠ', 'ㅡ', 'ㅣ', 'ㅐ', 'ㅒ', 'ㅔ', 'ㅖ', 'ㅘ', 'ㅙ', 'ㅚ', 'ㅝ', 'ㅞ', 'ㅟ', 'ㅢ'],
        'finals': ['ㄱ', 'ㄴ', 'ㄷ', 'ㄹ', 'ㅁ', 'ㅂ', 'ㅅ', 'ㅇ', 'ㅈ', 'ㅊ', 'ㅋ', 'ㅌ', 'ㅍ', 'ㅎ']
    },
    '고급': {
        'description': '2-3글자 단어 (받침 선택적)',
        'total_problems': 5,
        'word_lengths': [2, 3],
        'consonants': ['ㄱ', 'ㄲ', 'ㄴ', 'ㄷ', 'ㄸ', 'ㄹ', 'ㅁ', 'ㅂ', 'ㅃ', 'ㅅ', 'ㅆ', 'ㅇ', 'ㅈ', 'ㅉ', 'ㅊ', 'ㅋ', 'ㅌ', 'ㅍ', 'ㅎ'],
        'vowels': ['ㅏ', 'ㅑ', 'ㅓ', 'ㅕ', 'ㅗ', 'ㅛ', 'ㅜ', 'ㅠ', 'ㅡ', 'ㅣ', 'ㅐ', 'ㅒ', 'ㅔ', 'ㅖ', 'ㅘ', 'ㅙ', 'ㅚ', 'ㅝ', 'ㅞ', 'ㅟ', 'ㅢ'],
        'finals': ['', 'ㄱ', 'ㄴ', 'ㄷ', 'ㄹ', 'ㅁ', 'ㅂ', 'ㅅ', 'ㅇ', 'ㅈ', 'ㅊ', 'ㅋ', 'ㅌ', 'ㅍ', 'ㅎ']  # 빈 문자열 포함
    }
}

def combine_korean_chars(consonant, vowel, final=''):
    """자음, 모음, 받침을 조합해서 한글 완성형 생성"""
    consonant_index = ['ㄱ', 'ㄲ', 'ㄴ', 'ㄷ', 'ㄸ', 'ㄹ', 'ㅁ', 'ㅂ', 'ㅃ', 'ㅅ', 'ㅆ', 'ㅇ', 'ㅈ', 'ㅉ', 'ㅊ', 'ㅋ', 'ㅌ', 'ㅍ', 'ㅎ'].index(consonant)
    vowel_index = ['ㅏ', 'ㅐ', 'ㅑ', 'ㅒ', 'ㅓ', 'ㅔ', 'ㅕ', 'ㅖ', 'ㅗ', 'ㅘ', 'ㅙ', 'ㅚ', 'ㅛ', 'ㅜ', 'ㅝ', 'ㅞ', 'ㅟ', 'ㅠ', 'ㅡ', 'ㅢ', 'ㅣ'].index(vowel)
    
    if final:
        final_index = ['', 'ㄱ', 'ㄲ', 'ㄳ', 'ㄴ', 'ㄵ', 'ㄶ', 'ㄷ', 'ㄹ', 'ㄺ', 'ㄻ', 'ㄼ', 'ㄽ', 'ㄾ', 'ㄿ', 'ㅀ', 'ㅁ', 'ㅂ', 'ㅄ', 'ㅅ', 'ㅆ', 'ㅇ', 'ㅈ', 'ㅊ', 'ㅋ', 'ㅌ', 'ㅍ', 'ㅎ'].index(final)
    else:
        final_index = 0
    
    unicode_value = 0xAC00 + (consonant_index * 21 * 28) + (vowel_index * 28) + final_index
    return chr(unicode_value)

def generate_quiz_problems(mode, count=None):
    """퀴즈 문제 동적 생성"""
    if mode not in QUIZ_PROBLEMS:
        return []
    
    problems = []
    
    if mode == '낱말퀴즈':
        characters = QUIZ_PROBLEMS[mode]['characters']
        selected_count = count if count else len(characters)
        selected = random.sample(characters, min(selected_count, len(characters)))
        
        for char in selected:
            problems.append({
                'type': 'character',
                'question': char,
                'description': f'위 문자를 수어로 표현해주세요'
            })
    
    elif mode == '초급':
        for _ in range(10):
            consonant = random.choice(QUIZ_PROBLEMS[mode]['consonants'])
            vowel = random.choice(QUIZ_PROBLEMS[mode]['vowels'])
            syllable = combine_korean_chars(consonant, vowel)
            problems.append({
                'type': 'syllable',
                'question': syllable,
                'description': f'위 글자를 수어로 표현해주세요'
            })
    
    elif mode == '중급':
        for _ in range(5):
            consonant = random.choice(QUIZ_PROBLEMS[mode]['consonants'])
            vowel = random.choice(QUIZ_PROBLEMS[mode]['vowels'])
            final = random.choice(QUIZ_PROBLEMS[mode]['finals'])
            syllable = combine_korean_chars(consonant, vowel, final)
            problems.append({
                'type': 'syllable',
                'question': syllable,
                'description': f'위 글자를 수어로 표현해주세요'
            })
    
    elif mode == '고급':
        for _ in range(5):
            word_length = random.choice([2, 3])
            word = ""
            for _ in range(word_length):
                consonant = random.choice(QUIZ_PROBLEMS[mode]['consonants'])
                vowel = random.choice(QUIZ_PROBLEMS[mode]['vowels'])
                final = random.choice(QUIZ_PROBLEMS[mode]['finals'])
                syllable = combine_korean_chars(consonant, vowel, final)
                word += syllable
            problems.append({
                'type': 'word',
                'question': word,
                'description': f'위 단어를 수어로 표현해주세요'
            })
    
    return problems

# API 엔드포인트들

@quiz_bp.route('/api/quiz/<language>/skip', methods=['POST'])
@jwt_required()
def skip_quiz(language):
    """Quiz skip handling"""
    try:
        if language != 'ksl':
            return jsonify({'error': 'Only KSL is supported'}), 400
            
        user_id = get_jwt_identity()
        data = request.get_json()
        
        required_fields = ['session_id', 'level', 'question_type', 'question']
        for field in required_fields:
            if not data.get(field):
                return jsonify({'error': f'{field} is required'}), 400
        
        quiz = Quiz(
            user_id=user_id,
            session_id=data['session_id'],
            language=language,
            level=data['level'],
            question_type=data['question_type'],
            question=data['question'],
            correct_answer=data.get('correct_answer', ''),
            user_answer='SKIPPED',
            is_correct=False,
            response_time=data.get('response_time', 0),
            confidence_score=0.0
        )
        
        db.session.add(quiz)
        db.session.commit()
        
        return jsonify({
            'message': 'Question skipped successfully',
            'quiz': quiz.to_dict()
        }), 201
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

@quiz_bp.route('/api/quiz/<language>/statistics', methods=['GET'])
@jwt_required()
def get_quiz_statistics(language):
    """Get quiz statistics by level"""
    try:
        if language != 'ksl':
            return jsonify({'error': 'Only KSL is supported'}), 400

        user_id = get_jwt_identity()
        level = request.args.get('level', type=int)
        
        # 1. 기본 통계 계산 (가장 안전한 방식)
        base_query = Quiz.query.filter_by(user_id=user_id, language=language)
        if level:
            base_query = base_query.filter_by(level=level)

        total_quizzes = base_query.count()
        correct_quizzes = base_query.filter(Quiz.is_correct == True).count()
        skipped_quizzes = base_query.filter(Quiz.user_answer == 'SKIPPED').count()
        
        attempted_quizzes = total_quizzes - skipped_quizzes
        accuracy = (correct_quizzes / attempted_quizzes * 100) if attempted_quizzes > 0 else 0
        
        # 2. 레벨별 통계 계산 (Python으로 처리)
        level_breakdown = []
        
        # 각 레벨별로 개별 쿼리 실행
        levels_query = db.session.query(Quiz.level).filter_by(user_id=user_id, language=language).distinct()
        levels = [level_row.level for level_row in levels_query.all()]
        
        for level_num in levels:
            level_query = Quiz.query.filter_by(user_id=user_id, language=language, level=level_num)
            
            level_total = level_query.count()
            level_correct = level_query.filter(Quiz.is_correct == True).count()
            level_skipped = level_query.filter(Quiz.user_answer == 'SKIPPED').count()
            
            level_attempted = level_total - level_skipped
            level_accuracy = (level_correct / level_attempted * 100) if level_attempted > 0 else 0
            
            level_breakdown.append({
                'level': level_num,
                'total_questions': level_total,
                'correct_answers': level_correct,
                'skipped_questions': level_skipped,
                'accuracy': round(level_accuracy, 1)
            })
        
        return jsonify({
            'statistics': {
                'total_quizzes': total_quizzes,
                'correct_quizzes': correct_quizzes,
                'skipped_quizzes': skipped_quizzes,
                'attempted_quizzes': attempted_quizzes,
                'accuracy': round(accuracy, 1)
            },
            'level_breakdown': level_breakdown
        }), 200
        
    except Exception as e:
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500

@quiz_bp.route('/api/quiz/<language>/levels', methods=['GET'])
@jwt_required()
def get_quiz_levels(language):
    """Get available quiz levels with difficulty configuration"""
    try:
        if language != 'ksl':
            return jsonify({'error': 'Only KSL is supported'}), 400
        
        # QUIZ_PROBLEMS를 기반으로 레벨 정보 생성
        levels = [
            {
                'level': 1,
                'name': '초급',
                'description': QUIZ_PROBLEMS['초급']['description'],
                'difficulty': 'beginner',
                'total_questions': QUIZ_PROBLEMS['초급']['total_problems'],
                'characters': QUIZ_PROBLEMS['초급']['consonants'][:5],  # 처음 5개 자음
                'required_accuracy': 60
            },
            {
                'level': 2,
                'name': '중급',
                'description': QUIZ_PROBLEMS['중급']['description'],
                'difficulty': 'intermediate',
                'total_questions': QUIZ_PROBLEMS['중급']['total_problems'],
                'characters': QUIZ_PROBLEMS['중급']['consonants'][5:14] + QUIZ_PROBLEMS['중급']['vowels'][:1],  # 나머지 자음 + 모음 1개
                'required_accuracy': 80
            },
            {
                'level': 3,
                'name': '난말퀴즈',
                'description': QUIZ_PROBLEMS['낱말퀴즈']['description'],
                'difficulty': 'advanced',
                'total_questions': QUIZ_PROBLEMS['낱말퀴즈']['total_problems'],
                'characters': QUIZ_PROBLEMS['낱말퀴즈']['characters'],  # 전체 자모
                'required_accuracy': 52
            },
            {
                'level': 4,
                'name': '고급',
                'description': QUIZ_PROBLEMS['고급']['description'],
                'difficulty': 'expert',
                'total_questions': QUIZ_PROBLEMS['고급']['total_problems'],
                'characters': ['단어', '문장'],  # 고급은 단어/문장 표현
                'required_accuracy': 0
            }
        ]
        
        return jsonify({
            'language': language,
            'levels': levels
        }), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@quiz_bp.route('/api/quiz/<language>/generate', methods=['POST'])
@jwt_required()
def generate_quiz_questions(language):
    """Generate quiz questions based on level and mode"""
    try:
        if language != 'ksl':
            return jsonify({'error': 'Only KSL is supported'}), 400

        user_id = get_jwt_identity()
        data = request.get_json()
        
        level = data.get('level', 1)
        mode = data.get('mode', 'recognition')  # recognition, translation
        count = data.get('count', 5)
        
        level_config = None
        levels_response = get_quiz_levels(language)
        levels_data = levels_response[0].get_json()
        
        for lvl in levels_data['levels']:
            if lvl['level'] == level:
                level_config = lvl
                break
        
        if not level_config:
            return jsonify({'error': 'Invalid level'}), 400
        
        questions = []
        characters = level_config['characters']
        
        selected_chars = random.sample(characters, min(count, len(characters)))
        
        for i, char in enumerate(selected_chars):
            if mode == 'recognition':
                question = {
                    'id': i + 1,
                    'type': 'recognition',
                    'question': f'Show the sign for: {char}',
                    'target_sign': char,
                    'options': None,
                    'correct_answer': char,
                    'difficulty': level_config['difficulty'],
                    'time_limit': 30
                }
            else:  # translation
                options = [char]
                other_chars = [c for c in characters if c != char]
                options.extend(random.sample(other_chars, min(3, len(other_chars))))
                random.shuffle(options)
                
                question = {
                    'id': i + 1,
                    'type': 'translation',
                    'question': f'What does this sign mean?',
                    'sign_image': f'/static/signs/{language}/{char}.jpg',
                    'options': options,
                    'correct_answer': char,
                    'difficulty': level_config['difficulty'],
                    'time_limit': 15
                }
            
            questions.append(question)
        
        return jsonify({
            'level': level,
            'mode': mode,
            'total_questions': len(questions),
            'questions': questions,
            'level_config': level_config
        }), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# 추가된 API들

@quiz_bp.route('/api/quiz/<language>/submit', methods=['POST'])
@jwt_required()
def submit_quiz_answer(language):
    """퀴즈 답안 제출 및 저장"""
    try:
        if language != 'ksl':
            return jsonify({'error': 'Only KSL is supported'}), 400
        
        user_id = get_jwt_identity()
        data = request.get_json()
        
        required_fields = ['session_id', 'level', 'question_type', 'question', 'correct_answer', 'user_answer']
        for field in required_fields:
            if not data.get(field):
                return jsonify({'error': f'{field} is required'}), 400
        
        is_correct = data['user_answer'].strip().lower() == data['correct_answer'].strip().lower()
        
        quiz = Quiz(
            user_id=user_id,
            session_id=data['session_id'],
            language=language,
            level=data['level'],
            question_type=data['question_type'],
            question=data['question'],
            correct_answer=data['correct_answer'],
            user_answer=data['user_answer'],
            is_correct=is_correct,
            response_time=data.get('response_time', 0),
            confidence_score=data.get('confidence_score', 0.0)
        )
        
        db.session.add(quiz)
        db.session.commit()
        
        return jsonify({
            'message': 'Answer submitted successfully',
            'is_correct': is_correct,
            'quiz': quiz.to_dict()
        }), 201
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

@quiz_bp.route('/api/quiz/<language>/skipped', methods=['GET'])
@jwt_required()
def get_skipped_questions(language):
    """스킵된 문제 조회"""
    try:
        if language != 'ksl':
            return jsonify({'error': 'Only KSL is supported'}), 400
        
        user_id = get_jwt_identity()
        
        skipped_quizzes = Quiz.query.filter(
            Quiz.user_id == user_id,
            Quiz.language == language,
            Quiz.user_answer == 'SKIPPED'
        ).order_by(Quiz.created_at.desc()).all()
        
        # 모드별 그룹화
        grouped_skipped = {}
        for quiz in skipped_quizzes:
            mode = quiz.question_type
            if mode not in grouped_skipped:
                grouped_skipped[mode] = []
            grouped_skipped[mode].append(quiz.to_dict())
        
        return jsonify({
            'skipped_questions': [quiz.to_dict() for quiz in skipped_quizzes],
            'grouped_by_mode': grouped_skipped,
            'total_skipped': len(skipped_quizzes)
        }), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@quiz_bp.route('/api/quiz/<language>/mode/<mode>/generate', methods=['POST'])
@jwt_required()
def generate_quiz_by_mode(language, mode):
    """모드별 퀴즈 문제 생성 (기존 generate_quiz_problems 함수 활용)"""
    try:
        if language != 'ksl':
            return jsonify({'error': 'Only KSL is supported'}), 400
        
        if mode not in QUIZ_PROBLEMS:
            return jsonify({'error': 'Invalid quiz mode'}), 400
        
        user_id = get_jwt_identity()
        data = request.get_json() or {}
        count = data.get('count')
        
        problems = generate_quiz_problems(mode, count)
        
        return jsonify({
            'mode': mode,
            'description': QUIZ_PROBLEMS[mode]['description'],
            'total_problems': len(problems),
            'problems': problems
        }), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500