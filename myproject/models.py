from flask_sqlalchemy import SQLAlchemy
from datetime import datetime
import re

db = SQLAlchemy()

class User(db.Model):
    __tablename__ = 'users'
    
    id = db.Column(db.Integer, primary_key=True)
    nickname = db.Column(db.String(20), unique=True, nullable=False)
    email = db.Column(db.String(120), unique=True, nullable=False)
    password_hash = db.Column(db.String(128), nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # 학습 진도 관련
    total_words_learned = db.Column(db.Integer, default=0)
    current_level = db.Column(db.Integer, default=1)
    total_score = db.Column(db.Integer, default=0)
    streak_days = db.Column(db.Integer, default=0)
    
    def __repr__(self):
        return f'<User {self.nickname}>'
    
    @staticmethod
    def validate_nickname(nickname):
        """
        닉네임 유효성 검사
        - 20자리 이하
        - 영어, 한국어, 숫자만 허용
        - 특수문자 불허
        """
        if not nickname:
            return False, "닉네임을 입력해주세요."
        
        if len(nickname) > 20:
            return False, "닉네임은 20자리 이하로 입력해주세요."
        
        # 영어, 한국어, 숫자만 허용하는 정규식
        pattern = r'^[a-zA-Z가-힣0-9]+$'
        if not re.match(pattern, nickname):
            return False, "닉네임은 영어, 한국어, 숫자만 사용 가능합니다."
        
        return True, "유효한 닉네임입니다."
    
    @staticmethod
    def validate_email(email):
        """이메일 유효성 검사"""
        pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
        if not re.match(pattern, email):
            return False, "올바른 이메일 형식이 아닙니다."
        return True, "유효한 이메일입니다."

class LearningProgress(db.Model):
    __tablename__ = 'learning_progress'
    
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    category = db.Column(db.String(50), nullable=False)  # '기본 인사말', '숫자' 등
    progress = db.Column(db.Integer, default=0)  # 학습한 단어 수
    total_words = db.Column(db.Integer, default=0)  # 전체 단어 수
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    user = db.relationship('User', backref=db.backref('learning_progress', lazy=True))

class PracticeScore(db.Model):
    __tablename__ = 'practice_scores'
    
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    mode = db.Column(db.String(50), nullable=False)  # 'quiz', 'time_challenge' 등
    score = db.Column(db.Integer, nullable=False)
    accuracy = db.Column(db.Float, default=0.0)  # 정확도 (0.0 ~ 1.0)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    user = db.relationship('User', backref=db.backref('practice_scores', lazy=True))