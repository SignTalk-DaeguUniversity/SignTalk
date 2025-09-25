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

def test_recognition_session(token):
    """실시간 인식 세션 테스트"""
    print("\n=== 1. 실시간 인식 세션 시작 테스트 ===")
    url = f"{BASE_URL}/api/recognition/session/start"
    headers = {"Authorization": f"Bearer {token}"}
    data = {
        "language": "asl",
        "mode": "practice"
    }
    
    try:
        response = requests.post(url, json=data, headers=headers)
        print(f"Status Code: {response.status_code}")
        print(f"Response: {response.json()}")
        
        if response.status_code == 201:
            return response.json()['session_id']
        return None
    except Exception as e:
        print(f"❌ 오류: {e}")
        return None

def test_realtime_recognition(token):
    """실시간 인식 결과 저장 테스트"""
    print("\n=== 2. 실시간 인식 결과 저장 테스트 ===")
    url = f"{BASE_URL}/api/recognition/realtime"
    headers = {"Authorization": f"Bearer {token}"}
    data = {
        "language": "asl",
        "recognized_text": "A",
        "confidence_score": 0.92,
        "expected_text": "A",
        "session_duration": 5
    }
    
    try:
        response = requests.post(url, json=data, headers=headers)
        print(f"Status Code: {response.status_code}")
        print(f"Response: {response.json()}")
    except Exception as e:
        print(f"❌ 오류: {e}")

def test_practice_mode(token):
    """연습 모드 테스트"""
    print("\n=== 3. 연습 모드 테스트 ===")
    url = f"{BASE_URL}/api/recognition/practice"
    headers = {"Authorization": f"Bearer {token}"}
    data = {
        "recognized_text": "Hello",
        "confidence_score": 0.85
    }
    
    try:
        response = requests.post(url, json=data, headers=headers)
        print(f"Status Code: {response.status_code}")
        print(f"Response: {response.json()}")
    except Exception as e:
        print(f"❌ 오류: {e}")

def test_learning_mode(token):
    """학습 모드 테스트"""
    print("\n=== 4. 학습 모드 테스트 ===")
    url = f"{BASE_URL}/api/recognition/learning"
    headers = {"Authorization": f"Bearer {token}"}
    data = {
        "session_id": "test-session-123",
        "recognized_text": "B",
        "confidence_score": 0.78,
        "expected_text": "B"
    }
    
    try:
        response = requests.post(url, json=data, headers=headers)
        print(f"Status Code: {response.status_code}")
        print(f"Response: {response.json()}")
    except Exception as e:
        print(f"❌ 오류: {e}")

def test_recognition_stats(token):
    """인식 통계 테스트"""
    print("\n=== 5. 인식 통계 조회 테스트 ===")
    url = f"{BASE_URL}/api/recognition/stats?language=asl"
    headers = {"Authorization": f"Bearer {token}"}
    
    try:
        response = requests.get(url, headers=headers)
        print(f"Status Code: {response.status_code}")
        print(f"Response: {response.json()}")
    except Exception as e:
        print(f"❌ 오류: {e}")

def test_end_session(token, session_id):
    """세션 종료 테스트"""
    if not session_id:
        print("\n=== 세션 종료 테스트 건너뜀 (세션 ID 없음) ===")
        return
        
    print(f"\n=== 6. 세션 종료 테스트 (ID: {session_id}) ===")
    url = f"{BASE_URL}/api/recognition/session/{session_id}/end"
    headers = {"Authorization": f"Bearer {token}"}
    data = {
        "total_attempts": 10,
        "successful_attempts": 8,
        "average_confidence": 0.85,
        "duration_seconds": 120
    }
    
    try:
        response = requests.post(url, json=data, headers=headers)
        print(f"Status Code: {response.status_code}")
        print(f"Response: {response.json()}")
    except Exception as e:
        print(f"❌ 오류: {e}")

if __name__ == "__main__":
    print("🎯 실시간 수어 인식 API 테스트 시작\n")
    
    # 1. 토큰 받기
    token = get_auth_token()
    if not token:
        print("❌ 로그인 실패 - Flask 앱이 실행 중인지 확인하세요!")
        exit()
    
    # 2. 인식 세션 시작
    session_id = test_recognition_session(token)
    
    # 3. 실시간 인식 결과 저장
    test_realtime_recognition(token)
    
    # 4. 연습 모드 테스트
    test_practice_mode(token)
    
    # 5. 학습 모드 테스트
    test_learning_mode(token)
    
    # 6. 인식 통계 조회
    test_recognition_stats(token)
    
    # 7. 세션 종료
    test_end_session(token, session_id)
    
    print("\n🎉 실시간 인식 API 테스트 완료!")


def test_hand_shape_analysis(token):
    """손모양 분석 테스트"""
    print("\n=== 손모양 분석 테스트 ===")
    url = f"{BASE_URL}/api/recognition/analyze-hand"
    headers = {"Authorization": f"Bearer {token}"}
    data = {
        "target_sign": "A",
        "language": "asl",
        "session_id": "test-session-123",
        "image_data": "dummy_image_data"
    }
    
    try:
        response = requests.post(url, json=data, headers=headers)
        print(f"Status Code: {response.status_code}")
        print(f"Response: {response.json()}")
    except Exception as e:
        print(f"❌ 오류: {e}")
