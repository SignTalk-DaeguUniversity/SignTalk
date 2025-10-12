# 로그인/회원가입 API
from flask import Blueprint, request, jsonify
from flask_bcrypt import Bcrypt
from flask_jwt_extended import create_access_token, jwt_required, get_jwt_identity
from .models import db, User, Progress
from datetime import datetime
import re

auth_bp = Blueprint('auth', __name__)
bcrypt = Bcrypt()


@auth_bp.route('/api/auth/check-username', methods=['POST'])
def check_username():
    """아이디(username) 중복 확인 API"""
    try:
        data = request.get_json()
        
        # 입력 검증
        if not data or not data.get('username'):
            return jsonify({
                'available': False,
                'message': '아이디를 입력해주세요.'
            }), 400
        
        username = data['username'].strip()
        
        # 빈 값 체크
        if not username:
            return jsonify({
                'available': False,
                'message': '아이디를 입력해주세요.'
            }), 400
        
        # 아이디 길이 제한 확인 (5-20자)
        if len(username) < 5:
            return jsonify({
                'available': False,
                'message': '아이디는 5자 이상이어야 합니다.'
            }), 400
        
        if len(username) > 20:
            return jsonify({
                'available': False,
                'message': '아이디는 20자 이하여야 합니다.'
            }), 400
        

        # 아이디 형식 검증 (소문자, 숫자만 허용)
        username_pattern = r'^[a-z0-9]+$'
        if not re.match(username_pattern, username):
            return jsonify({
                'available': False,
                'message': '아이디는 소문자와 숫자만 사용 가능합니다.'
            }), 400


        # 데이터베이스에서 아이디 존재 여부 확인
        existing_user = User.query.filter_by(username=username).first()
        
        if existing_user:
            return jsonify({
                'available': False,
                'message': '이미 사용 중인 아이디입니다.'
            }), 200
        else:
            return jsonify({
                'available': True,
                'message': '사용 가능한 아이디입니다.'
            }), 200
            
    except Exception as e:
        return jsonify({
            'available': False,
            'message': '서버 오류가 발생했습니다.'
        }), 500


@auth_bp.route('/api/auth/check-nickname', methods=['POST'])
def check_nickname():
    """닉네임 중복 확인 API"""
    try:
        data = request.get_json()
        
        # 입력 검증
        if not data or not data.get('nickname'):
            return jsonify({
                'available': False,
                'message': '닉네임을 입력해주세요.'
            }), 400
        
        nickname = data['nickname'].strip()
        
        # 닉네임 유효성 검사
        is_valid, message = User.validate_nickname(nickname)
        if not is_valid:
            return jsonify({
                'available': False,
                'message': message
            }), 400
        
        # 데이터베이스에서 닉네임 존재 여부 확인
        existing_user = User.query.filter_by(nickname=nickname).first()
        
        if existing_user:
            return jsonify({
                'available': False,
                'message': '이미 사용 중인 닉네임입니다.'
            }), 200
        else:
            return jsonify({
                'available': True,
                'message': '사용 가능한 닉네임입니다.'
            }), 200
            
    except Exception as e:
        return jsonify({
            'available': False,
            'message': '서버 오류가 발생했습니다.'
        }), 500

@auth_bp.route('/api/auth/register', methods=['POST'])
def register():
    """회원가입 API"""
    try:
        data = request.get_json()
        
        # 입력 검증
        if not data or not data.get('username') or not data.get('nickname') or not data.get('email') or not data.get('password'):
            return jsonify({'error': '모든 필드를 입력해주세요.'}), 400
        
        # 닉네임 유효성 검사
        is_valid, message = User.validate_nickname(data['nickname'])
        if not is_valid:
            return jsonify({'error': message}), 400
        
        # 이메일 유효성 검사
        is_valid, message = User.validate_email(data['email'])
        if not is_valid:
            return jsonify({'error': message}), 400
        
        # 중복 확인
        if User.query.filter_by(username=data['username']).first():
            return jsonify({'error': '이미 존재하는 아이디입니다.'}), 400
            
        if User.query.filter_by(nickname=data['nickname']).first():
            return jsonify({'error': '이미 존재하는 닉네임입니다.'}), 400
        
        if User.query.filter_by(email=data['email']).first():
            return jsonify({'error': '이미 존재하는 이메일입니다.'}), 400
        
        # 비밀번호 검증
        password = data['password']
        
        # 길이 확인 (5자 이상)
        if len(password) < 5:
            return jsonify({'error': '비밀번호는 5자 이상이어야 합니다.'}), 400
        
        # 영문 포함 확인
        if not re.search(r'[a-zA-Z]', password):
            return jsonify({'error': '비밀번호에 영문이 포함되어야 합니다.'}), 400
        
        # 숫자 포함 확인
        if not re.search(r'[0-9]', password):
            return jsonify({'error': '비밀번호에 숫자가 포함되어야 합니다.'}), 400
        
        # 특수문자 포함 확인
        if not re.search(r'[!@#$%^&*(),.?":{}|<>]', password):
            return jsonify({'error': '비밀번호에 특수문자가 포함되어야 합니다.'}), 400
        
        # 사용자 생성
        password_hash = bcrypt.generate_password_hash(data['password']).decode('utf-8')
        user = User(
            username=data['username'],
            nickname=data['nickname'],
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

# JWT 블랙리스트 (메모리 기반 - 실제 운영에서는 Redis 등 사용 권장)
blacklisted_tokens = set()

@auth_bp.route('/api/auth/change-password', methods=['POST'])
@jwt_required()
def change_password():
    """비밀번호 변경 API"""
    try:
        user_id = get_jwt_identity()
        user = User.query.get(user_id)
        
        if not user:
            return jsonify({'error': '사용자를 찾을 수 없습니다.'}), 404
        
        data = request.get_json()
        
        # 입력 검증
        if not data or not data.get('current_password') or not data.get('new_password'):
            return jsonify({'error': '현재 비밀번호와 새 비밀번호를 입력해주세요.'}), 400
        
        # 현재 비밀번호 확인
        if not bcrypt.check_password_hash(user.password_hash, data['current_password']):
            return jsonify({'error': '현재 비밀번호가 올바르지 않습니다.'}), 400
        
        # 새 비밀번호 검증 (회원가입과 동일한 규칙)
        new_password = data['new_password']
        
        # 길이 확인 (5자 이상)
        if len(new_password) < 5:
            return jsonify({'error': '비밀번호는 5자 이상이어야 합니다.'}), 400
        
        # 영문 포함 확인
        if not re.search(r'[a-zA-Z]', new_password):
            return jsonify({'error': '비밀번호에 영문이 포함되어야 합니다.'}), 400
        
        # 숫자 포함 확인
        if not re.search(r'[0-9]', new_password):
            return jsonify({'error': '비밀번호에 숫자가 포함되어야 합니다.'}), 400
        
        # 특수문자 포함 확인
        if not re.search(r'[!@#$%^&*(),.?":{}|<>]', new_password):
            return jsonify({'error': '비밀번호에 특수문자가 포함되어야 합니다.'}), 400
        
        # 현재 비밀번호와 동일한지 확인
        if bcrypt.check_password_hash(user.password_hash, new_password):
            return jsonify({'error': '새 비밀번호는 현재 비밀번호와 달라야 합니다.'}), 400
        
        # 비밀번호 업데이트
        user.password_hash = bcrypt.generate_password_hash(new_password).decode('utf-8')
        db.session.commit()
        
        return jsonify({'message': '비밀번호가 성공적으로 변경되었습니다.'}), 200
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

@auth_bp.route('/api/auth/logout', methods=['POST'])
@jwt_required()
def logout():
    """로그아웃 API - JWT 토큰을 블랙리스트에 추가"""
    try:
        
        from flask import request
        from flask_jwt_extended import decode_token

        # Authorization 헤더에서 토큰 추출
        auth_header = request.headers.get('Authorization')
        if auth_header and auth_header.startswith('Bearer '):
            token = auth_header.split(' ')[1]  # "Bearer <token>"에서 토큰 부분만
            decoded_token = decode_token(token)
            jti = decoded_token['jti']
        else:
            return jsonify({'error': '토큰이 없습니다.'}), 401
              
        # 블랙리스트에 추가
        blacklisted_tokens.add(jti)
        
        return jsonify({'message': '성공적으로 로그아웃되었습니다.'}), 200
        
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
