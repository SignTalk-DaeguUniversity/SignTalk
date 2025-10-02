"""실제 운영용 데이터베이스 테이블 생성"""
from flask import Flask
from config import Config

# 경량 Flask 앱 생성
app = Flask(__name__)
app.config.from_object(Config)

# 기존 db 인스턴스 사용 (새로 만들지 않음)
from auth.models import db, User, Progress, Recognition, LearningSession, Achievement, Curriculum, Quiz

# db를 앱에 연결
db.init_app(app)

with app.app_context():
    print("\n" + "="*60)
    print("SignTalk 운영용 데이터베이스 초기화")
    print("="*60)
    
    print("\n📋 생성될 테이블:")
    print("   - users (사용자 정보)")
    print("   - progress (학습 진도)")
    print("   - recognitions (수어 인식 기록)")
    print("   - learning_sessions (학습 세션)")
    print("   - achievements (성취도/배지)")
    print("   - curriculum (커리큘럼)")
    print("   - quizzes (퀴즈 결과)")
    
    print("\n🔨 테이블 생성 중...")
    db.create_all()
    
    print("\n✅ 테이블 생성 완료!")
    
    print("\n" + "="*60)
    print("🎉 데이터베이스 준비 완료!")
    print("이제 Flutter 앱에서 회원가입/로그인이 가능합니다.")
    print("="*60 + "\n")
