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
            'email': self.email,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'last_login': self.last_login.isoformat() if self.last_login else None
        }

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
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    def to_dict(self):
        return {
            'id': self.id,
            'user_id': self.user_id,
            'language': self.language,
            'recognized_text': self.recognized_text,
            'confidence_score': self.confidence_score,
            'session_duration': self.session_duration,
            'created_at': self.created_at.isoformat() if self.created_at else None
        }
