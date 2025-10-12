# test/test_quiz_api.py
import requests
import json
import time

BASE_URL = "http://localhost:5002"

def test_auth_and_get_token():
    """Test user authentication and get JWT token"""
    print("=== 1. Authentication Test ===")
    
    # Register test user
    register_data = {
        "username": "quiztest001",
        "nickname": "퀴즈테스터",
        "email": "quiztest@test.com",
        "password": "testpass123!"
    }
    
    response = requests.post(f"{BASE_URL}/api/auth/register", json=register_data)
    if response.status_code == 201:
        print("✅ 회원가입 성공")
    elif response.status_code == 400 and "이미 존재" in response.text:
        print("ℹ️ 이미 존재하는 사용자")
    else:
        print(f"❌ 회원가입 실패: {response.text}")
    
    # Login
    login_data = {
        "username": "quiztest001",
        "password": "testpass123!"
    }
    
    response = requests.post(f"{BASE_URL}/api/auth/login", json=login_data)
    if response.status_code == 200:
        token = response.json()['access_token']
        print("✅ 로그인 성공")
        return token
    else:
        print(f"❌ 로그인 실패: {response.text}")
        return None

def test_quiz_levels(token):
    """Test quiz levels API"""
    print("\n=== 2. Quiz Levels Test ===")
    
    headers = {"Authorization": f"Bearer {token}"}
    
    # Test KSL levels
    response = requests.get(f"{BASE_URL}/api/quiz/ksl/levels", headers=headers)
    if response.status_code == 200:
        levels = response.json()['levels']
        print(f"✅ KSL 레벨 조회 성공: {len(levels)}개 레벨")
        for level in levels:
            print(f"   Level {level['level']}: {level['name']} - {level['total_questions']}문제")
    else:
        print(f"❌ KSL 레벨 조회 실패: {response.text}")
    
    # Test ASL levels
    response = requests.get(f"{BASE_URL}/api/quiz/asl/levels", headers=headers)
    if response.status_code == 200:
        levels = response.json()['levels']
        print(f"✅ ASL 레벨 조회 성공: {len(levels)}개 레벨")
        for level in levels:
            print(f"   Level {level['level']}: {level['name']} - {level['total_questions']}문제")
    else:
        print(f"❌ ASL 레벨 조회 실패: {response.text}")

def test_quiz_generation(token):
    """Test quiz question generation"""
    print("\n=== 3. Quiz Generation Test ===")
    
    headers = {"Authorization": f"Bearer {token}"}
    
    # Test KSL recognition mode
    quiz_data = {
        "level": 1,
        "mode": "recognition",
        "count": 3
    }
    
    response = requests.post(f"{BASE_URL}/api/quiz/ksl/generate", json=quiz_data, headers=headers)
    if response.status_code == 200:
        result = response.json()
        print(f"✅ KSL 인식 퀴즈 생성 성공: {result['total_questions']}문제")
        for q in result['questions'][:2]:  # Show first 2 questions
            print(f"   Q{q['id']}: {q['question']} (정답: {q['correct_answer']})")
    else:
        print(f"❌ KSL 퀴즈 생성 실패: {response.text}")
    
    # Test ASL translation mode
    quiz_data = {
        "level": 2,
        "mode": "translation",
        "count": 3
    }
    
    response = requests.post(f"{BASE_URL}/api/quiz/asl/generate", json=quiz_data, headers=headers)
    if response.status_code == 200:
        result = response.json()
        print(f"✅ ASL 번역 퀴즈 생성 성공: {result['total_questions']}문제")
        for q in result['questions'][:2]:
            print(f"   Q{q['id']}: {q['question']} (선택지: {q['options']})")
    else:
        print(f"❌ ASL 퀴즈 생성 실패: {response.text}")

def test_learning_session_and_quiz(token):
    """Test learning session with quiz submission"""
    print("\n=== 4. Learning Session & Quiz Test ===")
    
    headers = {"Authorization": f"Bearer {token}"}
    
    # Start learning session
    session_data = {
        "level": 1,
        "lesson_type": "quiz_practice"
    }
    
    response = requests.post(f"{BASE_URL}/api/learning/ksl/session/start", json=session_data, headers=headers)
    if response.status_code == 201:
        session_id = response.json()['session']['id']
        print(f"✅ 학습 세션 시작: ID {session_id}")
    else:
        print(f"❌ 학습 세션 시작 실패: {response.text}")
        return
    
    # Submit quiz answers
    quiz_results = [
        {
            "session_id": session_id,
            "level": 1,
            "question_type": "recognition",
            "question": "Show the sign for: ㄱ",
            "correct_answer": "ㄱ",
            "user_answer": "ㄱ",
            "is_correct": True,
            "response_time": 5.2,
            "confidence_score": 0.95
        },
        {
            "session_id": session_id,
            "level": 1,
            "question_type": "recognition",
            "question": "Show the sign for: ㄴ",
            "correct_answer": "ㄴ",
            "user_answer": "ㄷ",
            "is_correct": False,
            "response_time": 8.1,
            "confidence_score": 0.72
        }
    ]
    
    for quiz_data in quiz_results:
        response = requests.post(f"{BASE_URL}/api/learning/ksl/quiz", json=quiz_data, headers=headers)
        if response.status_code == 201:
            print(f"✅ 퀴즈 결과 저장: {quiz_data['user_answer']} ({'정답' if quiz_data['is_correct'] else '오답'})")
        else:
            print(f"❌ 퀴즈 결과 저장 실패: {response.text}")
    
    # Test skip functionality
    skip_data = {
        "session_id": session_id,
        "level": 1,
        "question_type": "recognition",
        "question": "Show the sign for: ㄷ",
        "correct_answer": "ㄷ",
        "response_time": 2.0
    }
    
    response = requests.post(f"{BASE_URL}/api/quiz/ksl/skip", json=skip_data, headers=headers)
    if response.status_code == 201:
        print("✅ 퀴즈 스킵 처리 성공")
    else:
        print(f"❌ 퀴즈 스킵 처리 실패: {response.text}")
    
    # End learning session
    end_data = {
        "duration": 300,
        "total_attempts": 3,
        "correct_attempts": 1,
        "completed": True
    }
    
    response = requests.post(f"{BASE_URL}/api/learning/ksl/session/{session_id}/end", json=end_data, headers=headers)
    if response.status_code == 200:
        session_result = response.json()['session']
        print(f"✅ 학습 세션 종료: 정확도 {session_result['accuracy_rate']:.1f}%")
    else:
        print(f"❌ 학습 세션 종료 실패: {response.text}")

def test_quiz_statistics(token):
    """Test quiz statistics API"""
    print("\n=== 5. Quiz Statistics Test ===")
    
    headers = {"Authorization": f"Bearer {token}"}
    
    # Get overall statistics
    response = requests.get(f"{BASE_URL}/api/quiz/ksl/statistics", headers=headers)
    if response.status_code == 200:
        stats = response.json()
        print("✅ 전체 퀴즈 통계:")
        print(f"   총 퀴즈: {stats['statistics']['total_quizzes']}개")
        print(f"   정답: {stats['statistics']['correct_quizzes']}개")
        print(f"   스킵: {stats['statistics']['skipped_quizzes']}개")
        print(f"   정확도: {stats['statistics']['accuracy']}%")
        
        if stats['level_breakdown']:
            print("   레벨별 통계:")
            for level_stat in stats['level_breakdown']:
                print(f"     Level {level_stat['level']}: {level_stat['accuracy']}% ({level_stat['correct_answers']}/{level_stat['total_questions']})")
    else:
        print(f"❌ 퀴즈 통계 조회 실패: {response.text}")
    
    # Get level-specific statistics
    response = requests.get(f"{BASE_URL}/api/quiz/ksl/statistics?level=1", headers=headers)
    if response.status_code == 200:
        stats = response.json()
        print(f"✅ Level 1 통계: 정확도 {stats['statistics']['accuracy']}%")
    else:
        print(f"❌ Level 1 통계 조회 실패: {response.text}")

def test_achievements(token):
    """Test achievements API"""
    print("\n=== 6. Achievements Test ===")
    
    headers = {"Authorization": f"Bearer {token}"}
    
    response = requests.get(f"{BASE_URL}/api/learning/ksl/achievements", headers=headers)
    if response.status_code == 200:
        achievements = response.json()
        print(f"✅ 성취도 조회 성공: {achievements['statistics']['total_achievements']}개 획득")
        print(f"   완료된 세션: {achievements['statistics']['total_completed_sessions']}개")
        print(f"   평균 정확도: {achievements['statistics']['average_accuracy']}%")
        
        if achievements['achievements']:
            print("   획득한 성취도:")
            for achievement in achievements['achievements'][:3]:  # Show first 3
                print(f"     {achievement['achievement_name']}: {achievement['description']}")
    else:
        print(f"❌ 성취도 조회 실패: {response.text}")

def main():
    """Run all quiz API tests"""
    print("🚀 SignTalk Quiz API 테스트 시작")
    print("=" * 50)
    
    # Get authentication token
    token = test_auth_and_get_token()
    if not token:
        print("❌ 인증 실패로 테스트 중단")
        return
    
    # Run all tests
    test_quiz_levels(token)
    test_quiz_generation(token)
    test_learning_session_and_quiz(token)
    test_quiz_statistics(token)
    test_achievements(token)
    
    print("\n" + "=" * 50)
    print("🎉 모든 퀴즈 API 테스트 완료!")
    print("\n📊 새로 구현된 API 엔드포인트:")
    print("   - POST /api/quiz/<language>/skip")
    print("   - GET /api/quiz/<language>/levels")
    print("   - POST /api/quiz/<language>/generate")
    print("   - GET /api/quiz/<language>/statistics")

if __name__ == "__main__":
    main()
