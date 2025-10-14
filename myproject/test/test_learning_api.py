# 학습모드 API 테스트

import requests
import json

BASE_URL = "http://localhost:5002"

def get_auth_token():
    """로그인해서 토큰 받기"""
    print("=== 로그인 시도 ===")
    url = f"{BASE_URL}/api/auth/login"
    data = {
        "username": "testuser",
        "password": "password123"
    }
    
    try:
        response = requests.post(url, json=data)
        print(f"로그인 Status Code: {response.status_code}")
        if response.status_code == 200:
            token = response.json().get('access_token')
            print(f"✅ 토큰 받음: {token[:50]}...")
            return token
        else:
            print(f"❌ 로그인 실패: {response.json()}")
            return None
    except Exception as e:
        print(f"❌ 연결 오류: {e}")
        return None

def test_curriculum(language, token):
    """커리큘럼 조회 테스트"""
    print(f"\n=== {language.upper()} 커리큘럼 조회 테스트 ===")
    url = f"{BASE_URL}/api/learning/{language}/curriculum?level=1"
    headers = {"Authorization": f"Bearer {token}"}
    
    try:
        response = requests.get(url, headers=headers)
        print(f"Status Code: {response.status_code}")
        print(f"Response: {response.json()}")
        return response.status_code == 200
    except Exception as e:
        print(f"❌ 오류: {e}")
        return False

def test_learning_session(language, token):
    """학습 세션 시작 테스트"""
    print(f"\n=== {language.upper()} 학습 세션 시작 테스트 ===")
    url = f"{BASE_URL}/api/learning/{language}/session/start"
    headers = {"Authorization": f"Bearer {token}"}
    data = {
        "level": 1,
        "lesson_type": "alphabet"
    }
    
    try:
        response = requests.post(url, json=data, headers=headers)
        print(f"Status Code: {response.status_code}")
        print(f"Response: {response.json()}")
        
        if response.status_code == 201:
            return response.json()['session']['id']
        return None
    except Exception as e:
        print(f"❌ 오류: {e}")
        return None

def test_submit_quiz(language, token, session_id):
    """퀴즈 제출 테스트"""
    print(f"\n=== {language.upper()} 퀴즈 제출 테스트 ===")
    url = f"{BASE_URL}/api/learning/{language}/quiz"
    headers = {"Authorization": f"Bearer {token}"}
    
    # 언어별 다른 테스트 데이터
    if language == "asl":
        question_data = {
            "question": "What is the sign for 'A'?",
            "correct_answer": "A",
            "user_answer": "A"
        }
    else:  # ksl
        question_data = {
            "question": "ㄱ 수어는?",
            "correct_answer": "ㄱ",
            "user_answer": "ㄱ"
        }
    
    data = {
        "session_id": session_id,
        "level": 1,
        "question_type": "recognition",
        **question_data,
        "is_correct": True,
        "response_time": 2.5,
        "confidence_score": 0.95
    }
    
    try:
        response = requests.post(url, json=data, headers=headers)
        print(f"Status Code: {response.status_code}")
        print(f"Response: {response.json()}")
    except Exception as e:
        print(f"❌ 오류: {e}")

def test_end_session(language, token, session_id):
    """학습 세션 종료 테스트"""
    print(f"\n=== {language.upper()} 학습 세션 종료 테스트 ===")
    url = f"{BASE_URL}/api/learning/{language}/session/{session_id}/end"
    headers = {"Authorization": f"Bearer {token}"}
    data = {
        "duration": 300,  # 5분
        "total_attempts": 10,
        "correct_attempts": 8,
        "completed": True
    }
    
    try:
        response = requests.post(url, json=data, headers=headers)
        print(f"Status Code: {response.status_code}")
        print(f"Response: {response.json()}")
    except Exception as e:
        print(f"❌ 오류: {e}")

def test_achievements(language, token):
    """성취도 조회 테스트"""
    print(f"\n=== {language.upper()} 성취도 조회 테스트 ===")
    url = f"{BASE_URL}/api/learning/{language}/achievements"
    headers = {"Authorization": f"Bearer {token}"}
    
    try:
        response = requests.get(url, headers=headers)
        print(f"Status Code: {response.status_code}")
        print(f"Response: {response.json()}")
    except Exception as e:
        print(f"❌ 오류: {e}")

def test_language_complete(language, token):
    """특정 언어의 전체 테스트"""
    print(f"\n🌍 === {language.upper()} 전체 테스트 시작 ===")
    
    # 1. 커리큘럼 조회
    test_curriculum(language, token)
    
    # 2. 학습 세션 시작
    session_id = test_learning_session(language, token)
    
    if session_id:
        # 3. 퀴즈 제출
        test_submit_quiz(language, token, session_id)
        
        # 4. 세션 종료
        test_end_session(language, token, session_id)
    
    # 5. 성취도 조회
    test_achievements(language, token)
    
    print(f"✅ {language.upper()} 테스트 완료!")

if __name__ == "__main__":
    print("🎓 SignTalk 학습 모드 API 테스트 시작\n")
    
    # 1. 토큰 받기
    token = get_auth_token()
    if not token:
        print("❌ 로그인 실패 - Flask 앱이 실행 중인지 확인하세요!")
        exit()
    
    # 2. ASL 테스트
    test_language_complete("asl", token)
    
    # 3. KSL 테스트  
    test_language_complete("ksl", token)
    
    print("\n🎉 모든 언어 API 테스트 완료!")