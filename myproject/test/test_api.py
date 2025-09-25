# test_api.py
import requests
import json

BASE_URL = "http://localhost:5002"

def test_register():
    """회원가입 테스트"""
    url = f"{BASE_URL}/api/auth/register"
    data = {
        "username": "testuser",
        "email": "test@example.com",
        "password": "password123"
    }
    
    response = requests.post(url, json=data)
    print("=== 회원가입 테스트 ===")
    print(f"Status Code: {response.status_code}")
    print(f"Response: {response.json()}")
    return response.json()

def test_login():
    """로그인 테스트"""
    url = f"{BASE_URL}/api/auth/login"
    data = {
        "username": "testuser",
        "password": "password123"
    }
    
    response = requests.post(url, json=data)
    print("\n=== 로그인 테스트 ===")
    print(f"Status Code: {response.status_code}")
    print(f"Response: {response.json()}")
    
    if response.status_code == 200:
        return response.json().get('access_token')
    return None

def test_profile(token):
    """프로필 조회 테스트"""
    url = f"{BASE_URL}/api/auth/profile"
    headers = {"Authorization": f"Bearer {token}"}
    
    response = requests.get(url, headers=headers)
    print("\n=== 프로필 조회 테스트 ===")
    print(f"Status Code: {response.status_code}")
    print(f"Response: {response.json()}")

def test_progress(token):
    """진도 조회 테스트"""
    url = f"{BASE_URL}/api/progress/asl"
    headers = {"Authorization": f"Bearer {token}"}
    
    response = requests.get(url, headers=headers)
    print("\n=== 진도 조회 테스트 ===")
    print(f"Status Code: {response.status_code}")
    print(f"Response: {response.json()}")

if __name__ == "__main__":
    print("🧪 SignTalk API 테스트 시작\n")
    
    # 1. 회원가입
    register_result = test_register()
    
    # 2. 로그인
    token = test_login()
    
    if token:
        # 3. 프로필 조회
        test_profile(token)
        
        # 4. 진도 조회
        test_progress(token)
    
    print("\n✅ 테스트 완료!")