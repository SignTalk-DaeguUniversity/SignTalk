# api/learning.py
from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from auth.models import db, LearningSession, Achievement, Curriculum, Quiz, Progress
from datetime import datetime
from sqlalchemy import func

learning_bp = Blueprint('learning', __name__)

@learning_bp.route('/api/learning/<language>/curriculum', methods=['GET'])
@jwt_required()
def get_curriculum(language):
    """레벨별 커리큘럼 조회"""
    try:
        if language not in ['asl', 'ksl']:
            return jsonify({'error': '유효하지 않은 언어입니다.'}), 400
        
        level = request.args.get('level', 1, type=int)
        
        curriculum = Curriculum.query.filter_by(
            language=language, 
            level=level, 
            is_active=True
        ).order_by(Curriculum.order_index).all()
        
        return jsonify({
            'curriculum': [c.to_dict() for c in curriculum],
            'total_lessons': len(curriculum)
        }), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@learning_bp.route('/api/learning/<language>/session/start', methods=['POST'])
@jwt_required()
def start_learning_session(language):
    """학습 세션 시작"""
    try:
        user_id = get_jwt_identity()
        data = request.get_json()
        
        if language not in ['asl', 'ksl']:
            return jsonify({'error': '유효하지 않은 언어입니다.'}), 400
        
        # 필수 필드 검증
        required_fields = ['level', 'lesson_type']
        for field in required_fields:
            if not data.get(field):
                return jsonify({'error': f'{field}는 필수입니다.'}), 400
        
        # 새 학습 세션 생성
        session = LearningSession(
            user_id=user_id,
            language=language,
            level=data['level'],
            lesson_type=data['lesson_type']
        )
        
        db.session.add(session)
        db.session.commit()
        
        return jsonify({
            'message': '학습 세션이 시작되었습니다.',
            'session': session.to_dict()
        }), 201
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

@learning_bp.route('/api/learning/<language>/session/<int:session_id>/end', methods=['POST'])
@jwt_required()
def end_learning_session(language, session_id):
    """학습 세션 종료"""
    try:
        user_id = get_jwt_identity()
        data = request.get_json()
        
        session = LearningSession.query.filter_by(
            id=session_id, 
            user_id=user_id
        ).first()
        
        if not session:
            return jsonify({'error': '세션을 찾을 수 없습니다.'}), 404
        
        # 세션 종료 정보 업데이트
        session.end_time = datetime.utcnow()
        session.duration = data.get('duration', 0)
        session.total_attempts = data.get('total_attempts', 0)
        session.correct_attempts = data.get('correct_attempts', 0)
        session.completed = data.get('completed', False)
        
        # 정확도 계산
        if session.total_attempts > 0:
            session.accuracy_rate = (session.correct_attempts / session.total_attempts) * 100
        
        # 진도 업데이트
        if session.completed and session.accuracy_rate >= 80:
            progress = Progress.query.filter_by(
                user_id=user_id, 
                language=language
            ).first()
            
            if progress:
                completed_lessons = progress.get_completed_lessons()
                lesson_key = f"level_{session.level}_{session.lesson_type}"
                
                if lesson_key not in completed_lessons:
                    completed_lessons.append(lesson_key)
                    progress.set_completed_lessons(completed_lessons)
                    progress.total_score += int(session.accuracy_rate)
        
        # 성취도 확인 및 부여
        check_and_award_achievements(user_id, language, session)
        
        db.session.commit()
        
        return jsonify({
            'message': '학습 세션이 종료되었습니다.',
            'session': session.to_dict()
        }), 200
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

@learning_bp.route('/api/learning/<language>/achievements', methods=['GET'])
@jwt_required()
def get_achievements(language):
    """성취도 조회"""
    try:
        user_id = get_jwt_identity()
        
        if language not in ['asl', 'ksl']:
            return jsonify({'error': '유효하지 않은 언어입니다.'}), 400
        
        achievements = Achievement.query.filter_by(
            user_id=user_id, 
            language=language
        ).order_by(Achievement.earned_at.desc()).all()
        
        # 통계 계산
        total_sessions = LearningSession.query.filter_by(
            user_id=user_id, 
            language=language,
            completed=True
        ).count()
        
        avg_accuracy = db.session.query(func.avg(LearningSession.accuracy_rate)).filter_by(
            user_id=user_id, 
            language=language,
            completed=True
        ).scalar() or 0
        
        return jsonify({
            'achievements': [a.to_dict() for a in achievements],
            'statistics': {
                'total_achievements': len(achievements),
                'total_completed_sessions': total_sessions,
                'average_accuracy': round(avg_accuracy, 2)
            }
        }), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@learning_bp.route('/api/learning/<language>/quiz', methods=['POST'])
@jwt_required()
def submit_quiz(language):
    """퀴즈 결과 저장"""
    try:
        user_id = get_jwt_identity()
        data = request.get_json()
        
        if language not in ['asl', 'ksl']:
            return jsonify({'error': '유효하지 않은 언어입니다.'}), 400
        
        # 필수 필드 검증
        required_fields = ['session_id', 'level', 'question_type', 'question', 'correct_answer']
        for field in required_fields:
            if not data.get(field):
                return jsonify({'error': f'{field}는 필수입니다.'}), 400
        
        # 퀴즈 결과 저장
        quiz = Quiz(
            user_id=user_id,
            session_id=data['session_id'],
            language=language,
            level=data['level'],
            question_type=data['question_type'],
            question=data['question'],
            correct_answer=data['correct_answer'],
            user_answer=data.get('user_answer'),
            is_correct=data.get('is_correct', False),
            response_time=data.get('response_time'),
            confidence_score=data.get('confidence_score')
        )
        
        db.session.add(quiz)
        db.session.commit()
        
        return jsonify({
            'message': '퀴즈 결과가 저장되었습니다.',
            'quiz': quiz.to_dict()
        }), 201
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

def check_and_award_achievements(user_id, language, session):
    """성취도 확인 및 부여"""
    try:
        # 레벨 완료 성취도
        if session.completed and session.accuracy_rate >= 90:
            existing = Achievement.query.filter_by(
                user_id=user_id,
                language=language,
                achievement_type='level_complete',
                level=session.level
            ).first()
            
            if not existing:
                achievement = Achievement(
                    user_id=user_id,
                    language=language,
                    achievement_type='level_complete',
                    achievement_name=f'Level {session.level} Master',
                    description=f'{language.upper()} Level {session.level} 완료 (90% 이상)',
                    level=session.level,
                    value=int(session.accuracy_rate)
                )
                db.session.add(achievement)
        
        # 정확도 마스터 성취도
        if session.accuracy_rate == 100:
            achievement = Achievement(
                user_id=user_id,
                language=language,
                achievement_type='accuracy_master',
                achievement_name='Perfect Score',
                description='100% 정확도 달성',
                level=session.level,
                value=100
            )
            db.session.add(achievement)
            
    except Exception as e:
        print(f"Achievement error: {e}")