# 로그인/회원가입 API
from flask import Blueprint, request, jsonify
from flask_bcrypt import Bcrypt
from flask_jwt_extended import create_access_token, jwt_required, get_jwt_identity
from .models import db, User, Progress
from datetime import datetime

auth_bp = Blueprint('auth', __name__)
bcrypt = Bcrypt()

@auth_bp.route('/api/auth/register', methods=['POST'])
def register():
    """회원가입 API"""
    try:
        data = request.get_json()
        
        # 입력 검증
        if not data or not data.get('username') or not data.get('email') or not data.get('password'):
            return jsonify({'error': '모든 필드를 입력해주세요.'}), 400
        
        # 중복 확인
        if User.query.filter_by(username=data['username']).first():
            return jsonify({'error': '이미 존재하는 사용자명입니다.'}), 400
        
        if User.query.filter_by(email=data['email']).first():
            return jsonify({'error': '이미 존재하는 이메일입니다.'}), 400
        
        # 사용자 생성
        password_hash = bcrypt.generate_password_hash(data['password']).decode('utf-8')
        user = User(
            username=data['username'],
            email=data['email'],
            password_hash=password_hash
        )
        
        db.session.add(user)
        db.session.commit()
        
        # 초기 진도 생성
        asl_progress = Progress(user_id=user.id, language='asl')
        ksl_progress = Progress(user_id=user.id, language='ksl')
        
        db.session.add(asl_progress)
        db.session.add(ksl_progress)
        db.session.commit()
        
        # JWT 토큰 생성
        access_token = create_access_token(identity=user.id)
        
        return jsonify({
            'message': '회원가입이 완료되었습니다.',
            'access_token': access_token,
            'user': user.to_dict()
        }), 201
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

@auth_bp.route('/api/auth/login', methods=['POST'])
def login():
    """로그인 API"""
    try:
        data = request.get_json()
        
        if not data or not data.get('username') or not data.get('password'):
            return jsonify({'error': '사용자명과 비밀번호를 입력해주세요.'}), 400
        
        user = User.query.filter_by(username=data['username']).first()
        
        if user and bcrypt.check_password_hash(user.password_hash, data['password']):
            # 로그인 시간 업데이트
            user.last_login = datetime.utcnow()
            db.session.commit()
            
            # JWT 토큰 생성
            access_token = create_access_token(identity=str(user.id))
            
            return jsonify({
                'message': '로그인 성공',
                'access_token': access_token,
                'user': user.to_dict()
            }), 200
        else:
            return jsonify({'error': '잘못된 사용자명 또는 비밀번호입니다.'}), 401
            
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@auth_bp.route('/api/auth/profile', methods=['GET'])
@jwt_required()
def get_profile():
    """프로필 조회 API"""
    try:
        user_id = get_jwt_identity()
        user = User.query.get(user_id)
        
        if not user:
            return jsonify({'error': '사용자를 찾을 수 없습니다.'}), 404
        
        # 진도 정보도 함께 반환
        asl_progress = Progress.query.filter_by(user_id=user_id, language='asl').first()
        ksl_progress = Progress.query.filter_by(user_id=user_id, language='ksl').first()
        
        return jsonify({
            'user': user.to_dict(),
            'progress': {
                'asl': asl_progress.to_dict() if asl_progress else None,
                'ksl': ksl_progress.to_dict() if ksl_progress else None
            }
        }), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500
