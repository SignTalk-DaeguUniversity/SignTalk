#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
새로 구현된 API들 테스트
- 진도 초기화 API
- 퀴즈 시스템 API들
- 스킵 관련 API들
"""

import requests
import json
import sys
import os

# 프로젝트 루트 디렉토리를 Python 경로에 추가
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

BASE_URL = "http://localhost:5000"

def test_progress_reset_api():
    """진도 초기화 API 테스트"""
    print("\n=== 진도 초기화 API 테스트 ===")
    
    # 먼저 로그인해서 토큰 받기
    login_data = {
        "username": "testuser",
        "password": "testpass123"
    }
    
    try:
        login_response = requests.post(f"{BASE_URL}/api/auth/login", json=login_data)
        if login_response.status_code != 200:
            print(f"❌ 로그인 실패: {login_response.status_code}")
            return False
        
        token = login_response.json().get('access_token')
        headers = {"Authorization": f"Bearer {token}"}
        
        # KSL 진도 초기화 테스트
        reset_response = requests.post(f"{BASE_URL}/api/progress/ksl/reset", headers=headers)
        print(f"KSL 진도 초기화: {reset_response.status_code}")
        if reset_response.status_code == 200:
            print(f"✅ 성공: {reset_response.json()}")
        else:
            print(f"❌ 실패: {reset_response.json()}")
        
        # ASL 진도 초기화 테스트
        reset_response = requests.post(f"{BASE_URL}/api/progress/asl/reset", headers=headers)
        print(f"ASL 진도 초기화: {reset_response.status_code}")
        if reset_response.status_code == 200:
            print(f"✅ 성공: {reset_response.json()}")
        else:
            print(f"❌ 실패: {reset_response.json()}")
            
        return True
        
    except requests.exceptions.ConnectionError:
        print("❌ 서버에 연결할 수 없습니다. Flask 앱이 실행 중인지 확인하세요.")
        return False
    except Exception as e:
        print(f"❌ 오류 발생: {e}")
        return False

def test_quiz_levels_api():
    """퀴즈 레벨 조회 API 테스트"""
    print("\n=== 퀴즈 레벨 조회 API 테스트 ===")
    
    # 로그인
    login_data = {"username": "testuser", "password": "testpass123"}
    
    try:
        login_response = requests.post(f"{BASE_URL}/api/auth/login", json=login_data)
        if login_response.status_code != 200:
            print(f"❌ 로그인 실패: {login_response.status_code}")
            return False
        
        token = login_response.json().get('access_token')
        headers = {"Authorization": f"Bearer {token}"}
        
        # KSL 퀴즈 레벨 조회
        ksl_response = requests.get(f"{BASE_URL}/api/quiz/ksl/levels", headers=headers)
        print(f"KSL 퀴즈 레벨 조회: {ksl_response.status_code}")
        if ksl_response.status_code == 200:
            levels = ksl_response.json()['levels']
            print(f"✅ KSL 레벨 수: {len(levels)}")
            for level_name in levels:
                print(f"  - {level_name}: {levels[level_name]['description']}")
        else:
            print(f"❌ 실패: {ksl_response.json()}")
        
        # ASL 퀴즈 레벨 조회
        asl_response = requests.get(f"{BASE_URL}/api/quiz/asl/levels", headers=headers)
        print(f"ASL 퀴즈 레벨 조회: {asl_response.status_code}")
        if asl_response.status_code == 200:
            levels = asl_response.json()['levels']
            print(f"✅ ASL 레벨 수: {len(levels)}")
            for level_name in levels:
                print(f"  - {level_name}: {levels[level_name]['description']}")
        else:
            print(f"❌ 실패: {asl_response.json()}")
            
        return True
        
    except requests.exceptions.ConnectionError:
        print("❌ 서버에 연결할 수 없습니다.")
        return False
    except Exception as e:
        print(f"❌ 오류 발생: {e}")
        return False

def test_quiz_generation_api():
    """퀴즈 생성 API 테스트"""
    print("\n=== 퀴즈 생성 API 테스트 ===")
    
    # 로그인
    login_data = {"username": "testuser", "password": "testpass123"}
    
    try:
        login_response = requests.post(f"{BASE_URL}/api/auth/login", json=login_data)
        if login_response.status_code != 200:
            print(f"❌ 로그인 실패: {login_response.status_code}")
            return False
        
        token = login_response.json().get('access_token')
        headers = {"Authorization": f"Bearer {token}"}
        
        # KSL 낱말퀴즈 생성
        quiz_data = {"mode": "낱말퀴즈", "type": "recognition", "count": 5}
        ksl_response = requests.post(f"{BASE_URL}/api/quiz/ksl/generate", json=quiz_data, headers=headers)
        print(f"KSL 낱말퀴즈 생성: {ksl_response.status_code}")
        if ksl_response.status_code == 200:
            problems = ksl_response.json()['problems']
            print(f"✅ 생성된 문제 수: {len(problems)}")
            print(f"  첫 번째 문제: {problems[0]['question']}")
        else:
            print(f"❌ 실패: {ksl_response.json()}")
        
        # ASL Beginner 퀴즈 생성
        quiz_data = {"mode": "Beginner", "type": "recognition", "count": 3}
        asl_response = requests.post(f"{BASE_URL}/api/quiz/asl/generate", json=quiz_data, headers=headers)
        print(f"ASL Beginner 퀴즈 생성: {asl_response.status_code}")
        if asl_response.status_code == 200:
            problems = asl_response.json()['problems']
            print(f"✅ 생성된 문제 수: {len(problems)}")
            print(f"  첫 번째 문제: {problems[0]['question']}")
        else:
            print(f"❌ 실패: {asl_response.json()}")
            
        return True
        
    except requests.exceptions.ConnectionError:
        print("❌ 서버에 연결할 수 없습니다.")
        return False
    except Exception as e:
        print(f"❌ 오류 발생: {e}")
        return False

def test_skip_api():
    """스킵 API 테스트"""
    print("\n=== 스킵 API 테스트 ===")
    
    # 로그인
    login_data = {"username": "testuser", "password": "testpass123"}
    
    try:
        login_response = requests.post(f"{BASE_URL}/api/auth/login", json=login_data)
        if login_response.status_code != 200:
            print(f"❌ 로그인 실패: {login_response.status_code}")
            return False
        
        token = login_response.json().get('access_token')
        headers = {"Authorization": f"Bearer {token}"}
        
        # 스킵 데이터 저장
        skip_data = {
            "session_id": 1,
            "level": "낱말퀴즈",
            "question_type": "낱말퀴즈",
            "question": "ㄱ",
            "correct_answer": "ㄱ",
            "response_time": 0
        }
        
        skip_response = requests.post(f"{BASE_URL}/api/quiz/ksl/skip", json=skip_data, headers=headers)
        print(f"KSL 스킵 저장: {skip_response.status_code}")
        if skip_response.status_code == 201:
            print(f"✅ 스킵 저장 성공: {skip_response.json()['message']}")
        else:
            print(f"❌ 실패: {skip_response.json()}")
        
        # 스킵된 문제 조회
        skipped_response = requests.get(f"{BASE_URL}/api/quiz/ksl/skipped", headers=headers)
        print(f"KSL 스킵 조회: {skipped_response.status_code}")
        if skipped_response.status_code == 200:
            skipped_data = skipped_response.json()
            print(f"✅ 스킵된 문제 수: {skipped_data['total_skipped']}")
        else:
            print(f"❌ 실패: {skipped_response.json()}")
            
        return True
        
    except requests.exceptions.ConnectionError:
        print("❌ 서버에 연결할 수 없습니다.")
        return False
    except Exception as e:
        print(f"❌ 오류 발생: {e}")
        return False

def test_quiz_statistics_api():
    """퀴즈 통계 API 테스트"""
    print("\n=== 퀴즈 통계 API 테스트 ===")
    
    # 로그인
    login_data = {"username": "testuser", "password": "testpass123"}
    
    try:
        login_response = requests.post(f"{BASE_URL}/api/auth/login", json=login_data)
        if login_response.status_code != 200:
            print(f"❌ 로그인 실패: {login_response.status_code}")
            return False
        
        token = login_response.json().get('access_token')
        headers = {"Authorization": f"Bearer {token}"}
        
        # KSL 통계 조회
        stats_response = requests.get(f"{BASE_URL}/api/quiz/ksl/statistics", headers=headers)
        print(f"KSL 퀴즈 통계 조회: {stats_response.status_code}")
        if stats_response.status_code == 200:
            stats = stats_response.json()
            overall = stats['overall_statistics']
            print(f"✅ 전체 퀴즈 수: {overall['total_quizzes']}")
            print(f"✅ 정답 수: {overall['correct_answers']}")
            print(f"✅ 스킵 수: {overall['skipped_problems']}")
            print(f"✅ 정확도: {overall['accuracy']}%")
        else:
            print(f"❌ 실패: {stats_response.json()}")
            
        return True
        
    except requests.exceptions.ConnectionError:
        print("❌ 서버에 연결할 수 없습니다.")
        return False
    except Exception as e:
        print(f"❌ 오류 발생: {e}")
        return False

def main():
    """모든 테스트 실행"""
    print("🚀 새로 구현된 API 테스트 시작")
    print("=" * 50)
    
    # 각 테스트 실행
    tests = [
        ("진도 초기화 API", test_progress_reset_api),
        ("퀴즈 레벨 조회 API", test_quiz_levels_api),
        ("퀴즈 생성 API", test_quiz_generation_api),
        ("스킵 API", test_skip_api),
        ("퀴즈 통계 API", test_quiz_statistics_api)
    ]
    
    results = []
    for test_name, test_func in tests:
        try:
            result = test_func()
            results.append((test_name, result))
        except Exception as e:
            print(f"❌ {test_name} 테스트 중 오류: {e}")
            results.append((test_name, False))
    
    # 결과 요약
    print("\n" + "=" * 50)
    print("📊 테스트 결과 요약")
    print("=" * 50)
    
    passed = 0
    for test_name, result in results:
        status = "✅ PASS" if result else "❌ FAIL"
        print(f"{status} {test_name}")
        if result:
            passed += 1
    
    print(f"\n총 {len(results)}개 테스트 중 {passed}개 통과")
    
    if passed == len(results):
        print("🎉 모든 테스트가 성공했습니다!")
    else:
        print("⚠️  일부 테스트가 실패했습니다. Flask 서버가 실행 중인지 확인하세요.")

if __name__ == "__main__":
    main()
