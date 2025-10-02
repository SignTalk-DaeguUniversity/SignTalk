import sys
import os

# 상위 디렉토리(myproject)를 Python 경로에 추가
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app import app, db
from auth.models import User

def check_database():
    with app.app_context():
        # 모든 사용자 조회
        users = User.query.all()
        
        print(f"\n=== 데이터베이스 사용자 목록 (총 {len(users)}명) ===\n")
        
        if not users:
            print("등록된 사용자가 없습니다.")
        else:
            for user in users:
                print(f"ID: {user.id}")
                print(f"아이디: {user.username}")
                print(f"닉네임: {user.nickname}")
                print(f"이메일: {user.email}")
                print(f"가입일: {user.created_at}")
                print(f"마지막 로그인: {user.last_login}")
                print("-" * 50)

if __name__ == '__main__':
    check_database()
