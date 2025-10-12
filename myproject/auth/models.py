# 사용자 데이터베이스 모델
from flask_sqlalchemy import SQLAlchemy
from flask_login import UserMixin
from datetime import datetime
import json

db = SQLAlchemy()

class User(UserMixin, db.Model):
    __tablename__ = 'users'
    
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True, nullable=False)
    nickname = db.Column(db.String(20), unique=True, nullable=False)  # 닉네임 추가
    email = db.Column(db.String(120), unique=True, nullable=False)
    password_hash = db.Column(db.String(128), nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    last_login = db.Column(db.DateTime)
    
    # 관계 설정
    progress = db.relationship('Progress', backref='user', lazy=True)
    recognitions = db.relationship('Recognition', backref='user', lazy=True)
    
    def to_dict(self):
        return {
            'id': self.id,
            'username': self.username,
            'nickname': self.nickname,
            'email': self.email,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'last_login': self.last_login.isoformat() if self.last_login else None
        }
    
    @staticmethod
    def validate_nickname(nickname):
        """
        닉네임 유효성 검사
        - 20자리 이하
        - 영어, 한국어, 숫자만 허용
        - 특수문자 불허
        """
        import re
        
        if not nickname:
            return False, "닉네임을 입력해주세요."
        
        if len(nickname) > 20:
            return False, "닉네임은 20자리 이하로 입력해주세요."
        
        if len(nickname) < 2:
            return False, "닉네임은 2자리 이상 입력해주세요."
        
        # 영어, 한국어, 숫자만 허용하는 정규식
        pattern = r'^[a-zA-Z가-힣0-9]+$'
        if not re.match(pattern, nickname):
            return False, "닉네임은 영어, 한국어, 숫자만 사용 가능합니다."
        
        return True, "유효한 닉네임입니다."
    
    @staticmethod
    def validate_email(email):
        """이메일 유효성 검사"""
        import re
        pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
        if not re.match(pattern, email):
            return False, "올바른 이메일 형식이 아닙니다."
        return True, "유효한 이메일입니다."

class Progress(db.Model):
    __tablename__ = 'progress'
    
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    language = db.Column(db.String(10), nullable=False)  # 'asl' or 'ksl'
    level = db.Column(db.Integer, default=1)
    completed_lessons = db.Column(db.Text)  # JSON string
    total_score = db.Column(db.Integer, default=0)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    def get_completed_lessons(self):
        return json.loads(self.completed_lessons) if self.completed_lessons else []
    
    def set_completed_lessons(self, lessons):
        self.completed_lessons = json.dumps(lessons)
    
    def to_dict(self):
        return {
            'id': self.id,
            'user_id': self.user_id,
            'language': self.language,
            'level': self.level,
            'completed_lessons': self.get_completed_lessons(),
            'total_score': self.total_score,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None
        }

class Recognition(db.Model):
    __tablename__ = 'recognitions'
    
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    language = db.Column(db.String(10), nullable=False)  # 'asl' or 'ksl'
    recognized_text = db.Column(db.Text, nullable=False)
    confidence_score = db.Column(db.Float)
    session_duration = db.Column(db.Integer)  # seconds
    session_id = db.Column(db.String(36))  # 세션 연결 추가
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    def to_dict(self):
        return {
            'id': self.id,
            'user_id': self.user_id,
            'language': self.language,
            'recognized_text': self.recognized_text,
            'confidence_score': self.confidence_score,
            'session_duration': self.session_duration,
            'session_id': self.session_id,
            'created_at': self.created_at.isoformat() if self.created_at else None
        }

class LearningSession(db.Model):
    """학습 세션 모델"""
    __tablename__ = 'learning_sessions'
    
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    language = db.Column(db.String(10), nullable=False)  # 'asl' or 'ksl'
    level = db.Column(db.Integer, nullable=False)
    lesson_type = db.Column(db.String(50), nullable=False)  # 'alphabet', 'words', 'sentences'
    start_time = db.Column(db.DateTime, default=datetime.utcnow)
    end_time = db.Column(db.DateTime)
    duration = db.Column(db.Integer)  # seconds
    total_attempts = db.Column(db.Integer, default=0)
    correct_attempts = db.Column(db.Integer, default=0)
    accuracy_rate = db.Column(db.Float, default=0.0)
    completed = db.Column(db.Boolean, default=False)
    
    def to_dict(self):
        return {
            'id': self.id,
            'user_id': self.user_id,
            'language': self.language,
            'level': self.level,
            'lesson_type': self.lesson_type,
            'start_time': self.start_time.isoformat() if self.start_time else None,
            'end_time': self.end_time.isoformat() if self.end_time else None,
            'duration': self.duration,
            'total_attempts': self.total_attempts,
            'correct_attempts': self.correct_attempts,
            'accuracy_rate': self.accuracy_rate,
            'completed': self.completed
        }

class Achievement(db.Model):
    """성취도/배지 모델"""
    __tablename__ = 'achievements'
    
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    language = db.Column(db.String(10), nullable=False)
    achievement_type = db.Column(db.String(50), nullable=False)  # 'level_complete', 'accuracy_master', 'streak'
    achievement_name = db.Column(db.String(100), nullable=False)
    description = db.Column(db.Text)
    earned_at = db.Column(db.DateTime, default=datetime.utcnow)
    level = db.Column(db.Integer)
    value = db.Column(db.Integer)  # 연속 일수, 정확도 등
    
    def to_dict(self):
        return {
            'id': self.id,
            'user_id': self.user_id,
            'language': self.language,
            'achievement_type': self.achievement_type,
            'achievement_name': self.achievement_name,
            'description': self.description,
            'earned_at': self.earned_at.isoformat() if self.earned_at else None,
            'level': self.level,
            'value': self.value
        }

class Curriculum(db.Model):
    """커리큘럼 모델"""
    __tablename__ = 'curriculum'
    
    id = db.Column(db.Integer, primary_key=True)
    language = db.Column(db.String(10), nullable=False)
    level = db.Column(db.Integer, nullable=False)
    lesson_type = db.Column(db.String(50), nullable=False)
    lesson_name = db.Column(db.String(100), nullable=False)
    description = db.Column(db.Text)
    content = db.Column(db.Text)  # JSON string with lesson content
    required_accuracy = db.Column(db.Float, default=80.0)  # 통과 기준 정확도
    estimated_duration = db.Column(db.Integer)  # 예상 소요 시간 (분)
    order_index = db.Column(db.Integer, default=0)
    is_active = db.Column(db.Boolean, default=True)
    
    def get_content(self):
        return json.loads(self.content) if self.content else {}
    
    def set_content(self, content_dict):
        self.content = json.dumps(content_dict)
    
    def to_dict(self):
        return {
            'id': self.id,
            'language': self.language,
            'level': self.level,
            'lesson_type': self.lesson_type,
            'lesson_name': self.lesson_name,
            'description': self.description,
            'content': self.get_content(),
            'required_accuracy': self.required_accuracy,
            'estimated_duration': self.estimated_duration,
            'order_index': self.order_index,
            'is_active': self.is_active
        }

class Quiz(db.Model):
    """퀴즈 결과 모델"""
    __tablename__ = 'quizzes'
    
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    session_id = db.Column(db.Integer, db.ForeignKey('learning_sessions.id'), nullable=False)
    language = db.Column(db.String(10), nullable=False)
    level = db.Column(db.Integer, nullable=False)
    question_type = db.Column(db.String(50), nullable=False)  # 'recognition', 'translation'
    question = db.Column(db.Text, nullable=False)
    correct_answer = db.Column(db.String(100), nullable=False)
    user_answer = db.Column(db.String(100))
    is_correct = db.Column(db.Boolean, default=False)
    response_time = db.Column(db.Float)  # seconds
    confidence_score = db.Column(db.Float)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    def to_dict(self):
        return {
            'id': self.id,
            'user_id': self.user_id,
            'session_id': self.session_id,
            'language': self.language,
            'level': self.level,
            'question_type': self.question_type,
            'question': self.question,
            'correct_answer': self.correct_answer,
            'user_answer': self.user_answer,
            'is_correct': self.is_correct,
            'response_time': self.response_time,
            'confidence_score': self.confidence_score,
            'created_at': self.created_at.isoformat() if self.created_at else None
        }