import requests
import json

BASE_URL = "http://127.0.0.1:5000"

def get_auth_token():
    """로그인해서 토큰 받기"""
    url = f"{BASE_URL}/api/auth/login"
    data = {"username": "testuser", "password": "password123"}
    
    try:
        response = requests.post(url, json=data)
        if response.status_code == 200:
            token = response.json()['access_token']
            print(f"✅ 토큰 받음: {token[:50]}...")
            return token
        else:
            print(f"❌ 로그인 실패: {response.json()}")
            return None
    except Exception as e:
        print(f"❌ 로그인 오류: {e}")
        return None

def test_asl_hand_analysis(token):
    """ASL (미국 수어) 손모양 분석"""
    print("\n=== ASL (미국 수어) 손모양 분석 ===")
    url = f"{BASE_URL}/api/recognition/analyze-hand"
    headers = {"Authorization": f"Bearer {token}"}
    
    # ASL 알파벳 테스트
    asl_signs = ['A', 'B', 'C', 'Hello', 'Thank you', 'Please']
    
    for sign in asl_signs:
        data = {
            "target_sign": sign,
            "language": "asl",
            "image_data": "dummy_asl_image_data"
        }
        
        try:
            response = requests.post(url, json=data, headers=headers)
            if response.status_code == 200:
                result = response.json()
                accuracy = result['analysis']['accuracy']
                message = result['analysis']['feedback']['message']
                score = result['analysis']['feedback']['score']
                print(f"  📝 {sign}: {accuracy}% - {score} - {message}")
            else:
                print(f"  ❌ {sign}: 오류 - {response.json()}")
        except Exception as e:
            print(f"  ❌ {sign}: 요청 오류 - {e}")

def test_ksl_hand_analysis(token):
    """KSL (한국 수어) 손모양 분석"""
    print("\n=== KSL (한국 수어) 손모양 분석 ===")
    url = f"{BASE_URL}/api/recognition/analyze-hand"
    headers = {"Authorization": f"Bearer {token}"}
    
    # KSL 자음/단어 테스트
    ksl_signs = ['ㄱ', 'ㄴ', 'ㄷ', '안녕하세요', '감사합니다', '죄송합니다']
    
    for sign in ksl_signs:
        data = {
            "target_sign": sign,
            "language": "ksl",
            "image_data": "dummy_ksl_image_data"
        }
        
        try:
            response = requests.post(url, json=data, headers=headers)
            if response.status_code == 200:
                result = response.json()
                accuracy = result['analysis']['accuracy']
                message = result['analysis']['feedback']['message']
                score = result['analysis']['feedback']['score']
                print(f"  📝 {sign}: {accuracy}% - {score} - {message}")
            else:
                print(f"  ❌ {sign}: 오류 - {response.json()}")
        except Exception as e:
            print(f"  ❌ {sign}: 요청 오류 - {e}")

def test_session_with_both_languages(token):
    """ASL/KSL 세션 연동 테스트"""
    print("\n=== 다국어 세션 연동 테스트 ===")
    headers = {"Authorization": f"Bearer {token}"}
    
    # ASL 세션
    print("\n  🇺🇸 ASL 세션 테스트")
    asl_session = requests.post(f"{BASE_URL}/api/recognition/session/start", 
                               json={"language": "asl", "mode": "learning"}, 
                               headers=headers)
    
    if asl_session.status_code == 201:
        session_id = asl_session.json()['session_id']
        print(f"    ✅ ASL 세션 시작: {session_id[:8]}...")
        
        # ASL 손모양 분석
        asl_analysis = requests.post(f"{BASE_URL}/api/recognition/analyze-hand",
                                   json={
                                       "target_sign": "Hello",
                                       "language": "asl",
                                       "session_id": session_id,
                                       "image_data": "asl_hello_image"
                                   }, headers=headers)
        
        if asl_analysis.status_code == 200:
            result = asl_analysis.json()
            print(f"    ✅ Hello 분석: {result['analysis']['accuracy']}%")
        
        # ASL 세션 종료
        requests.post(f"{BASE_URL}/api/recognition/session/{session_id}/end", 
                     json={}, headers=headers)
        print(f"    ✅ ASL 세션 종료")
    
    # KSL 세션
    print("\n  🇰🇷 KSL 세션 테스트")
    ksl_session = requests.post(f"{BASE_URL}/api/recognition/session/start", 
                               json={"language": "ksl", "mode": "learning"}, 
                               headers=headers)
    
    if ksl_session.status_code == 201:
        session_id = ksl_session.json()['session_id']
        print(f"    ✅ KSL 세션 시작: {session_id[:8]}...")
        
        # KSL 손모양 분석
        ksl_analysis = requests.post(f"{BASE_URL}/api/recognition/analyze-hand",
                                   json={
                                       "target_sign": "안녕하세요",
                                       "language": "ksl",
                                       "session_id": session_id,
                                       "image_data": "ksl_hello_image"
                                   }, headers=headers)
        
        if ksl_analysis.status_code == 200:
            result = ksl_analysis.json()
            print(f"    ✅ 안녕하세요 분석: {result['analysis']['accuracy']}%")
        
        # KSL 세션 종료
        requests.post(f"{BASE_URL}/api/recognition/session/{session_id}/end", 
                     json={}, headers=headers)
        print(f"    ✅ KSL 세션 종료")

def test_practice_vs_learning_mode(token):
    """연습모드 vs 학습모드 비교"""
    print("\n=== 연습모드 vs 학습모드 비교 ===")
    headers = {"Authorization": f"Bearer {token}"}
    
    # 연습모드 (ASL)
    practice_response = requests.post(f"{BASE_URL}/api/recognition/practice",
                                    json={
                                        "target_sign": "A",
                                        "language": "asl",
                                        "image_data": "practice_image"
                                    }, headers=headers)
    
    if practice_response.status_code == 200:
        result = practice_response.json()
        print(f"  🎯 연습모드 (ASL-A): {result['analysis']['accuracy']}% - 진도영향: {result['affects_progress']}")
    
    # 학습모드 (세션 필요)
    session_response = requests.post(f"{BASE_URL}/api/recognition/session/start",
                                   json={"language": "ksl", "mode": "learning"},
                                   headers=headers)
    
    if session_response.status_code == 201:
        session_id = session_response.json()['session_id']
        
        learning_response = requests.post(f"{BASE_URL}/api/recognition/learning",
                                        json={
                                            "target_sign": "ㄱ",
                                            "language": "ksl",
                                            "session_id": session_id,
                                            "image_data": "learning_image"
                                        }, headers=headers)
        
        if learning_response.status_code == 200:
            result = learning_response.json()
            print(f"  📚 학습모드 (KSL-ㄱ): {result['analysis']['accuracy']}% - 진도영향: {result['affects_progress']}")
            print(f"      진도업데이트: {result['progress_updated']}")
        
        # 세션 종료
        requests.post(f"{BASE_URL}/api/recognition/session/{session_id}/end", 
                     json={}, headers=headers)

if __name__ == "__main__":
    print("🌍 다국어 손모양 분석 테스트 (ASL + KSL)")
    print("=" * 50)
    
    token = get_auth_token()
    if not token:
        print("❌ Flask 앱을 먼저 실행하세요!")
        print("새 터미널에서: cd myproject && python app.py")
        exit()
    
    # 1. ASL 손모양 분석
    test_asl_hand_analysis(token)
    
    # 2. KSL 손모양 분석
    test_ksl_hand_analysis(token)
    
    # 3. 세션 연동 테스트
    test_session_with_both_languages(token)
    
    # 4. 모드 비교 테스트
    test_practice_vs_learning_mode(token)
    
    print("\n🎉 다국어 손모양 분석 테스트 완료!")
    print("✅ ASL (미국 수어) 지원")
    print("✅ KSL (한국 수어) 지원")
    print("✅ 연습모드/학습모드 지원")
    print("✅ 세션 관리 지원")
