
# 학습진도 API
from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from auth.models import db, Progress, Recognition
from api.quiz import combine_korean_chars


progress_bp = Blueprint('progress', __name__)

@progress_bp.route('/api/progress/<language>', methods=['GET'])
@jwt_required()
def get_progress(language):
    """특정 언어의 학습 진도 조회"""
    try:
        user_id = get_jwt_identity()
        
        if language not in ['asl', 'ksl']:
            return jsonify({'error': '유효하지 않은 언어입니다.'}), 400
        
        progress = Progress.query.filter_by(user_id=user_id, language=language).first()
        
        if not progress:
            return jsonify({'error': '진도 정보를 찾을 수 없습니다.'}), 404
        
        return jsonify({'progress': progress.to_dict()}), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@progress_bp.route('/api/progress/<language>/update', methods=['POST'])
@jwt_required()
def update_progress(language):
    """학습 진도 업데이트"""
    try:
        user_id = get_jwt_identity()
        data = request.get_json()
        
        if language not in ['asl', 'ksl']:
            return jsonify({'error': '유효하지 않은 언어입니다.'}), 400
        
        progress = Progress.query.filter_by(user_id=user_id, language=language).first()
        
        if not progress:
            return jsonify({'error': '진도 정보를 찾을 수 없습니다.'}), 404
        
        # 진도 업데이트
        if 'level' in data:
            progress.level = data['level']
        
        if 'completed_lessons' in data:
            progress.set_completed_lessons(data['completed_lessons'])
        
        if 'total_score' in data:
            progress.total_score = data['total_score']
        
        db.session.commit()
        
        return jsonify({
            'message': '진도가 업데이트되었습니다.',
            'progress': progress.to_dict()
        }), 200
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

@progress_bp.route('/api/recognition/save', methods=['POST'])
@jwt_required()
def save_recognition():
    """수어 인식 결과 저장"""
    try:
        user_id = get_jwt_identity()
        data = request.get_json()
        
        if not data or not data.get('language') or not data.get('recognized_text'):
            return jsonify({'error': '필수 필드가 누락되었습니다.'}), 400
        
        if data['language'] not in ['asl', 'ksl']:
            return jsonify({'error': '유효하지 않은 언어입니다.'}), 400
        
        recognition = Recognition(
            user_id=user_id,
            language=data['language'],
            recognized_text=data['recognized_text'],
            confidence_score=data.get('confidence_score'),
            session_duration=data.get('session_duration')
        )
        
        db.session.add(recognition)
        db.session.commit()
        
        return jsonify({
            'message': '인식 결과가 저장되었습니다.',
            'recognition': recognition.to_dict()
        }), 201
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

@progress_bp.route('/api/progress/<language>/reset', methods=['POST'])
@jwt_required()
def reset_progress(language):
    """학습 진도 초기화"""
    try:
        user_id = get_jwt_identity()
        
        if language not in ['asl', 'ksl']:
            return jsonify({'error': '유효하지 않은 언어입니다.'}), 400
        
        progress = Progress.query.filter_by(user_id=user_id, language=language).first()
        
        if not progress:
            # 진도 정보가 없으면 새로 생성
            progress = Progress(
                user_id=user_id,
                language=language,
                level=1,
                completed_lessons='[]',
                total_score=0
            )
            db.session.add(progress)
        else:
            # 기존 진도 초기화
            progress.level = 1
            progress.set_completed_lessons([])
            progress.total_score = 0
        
        db.session.commit()
        
        return jsonify({
            'message': '진도가 초기화되었습니다.',
            'progress': progress.to_dict()
        }), 200
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500