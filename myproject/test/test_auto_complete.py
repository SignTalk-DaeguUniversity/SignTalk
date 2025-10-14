# test/test_auto_complete.py
import requests
import json
import time
from datetime import datetime
import random

BASE_URL = "http://localhost:5002"

class AutoCompleteTest:
    def __init__(self):
        self.token = None
        self.user_id = None
        self.session_ids = []
        self.test_results = []
        
    def log_result(self, api_name, success, message="", response_data=None):
        """테스트 결과 로깅"""
        status = "✅" if success else "❌"
        print(f"{status} {api_name}")
        if message:
            print(f"   └─ {message}")
        
        self.test_results.append({
            'api': api_name,
            'success': success,
            'message': message,
            'data': response_data
        })
    
    def setup_test_user(self):
        """테스트 사용자 자동 생성 및 로그인"""
        print("🔧 테스트 환경 설정 중...")
        
        # 랜덤 사용자 생성
        timestamp = int(time.time())
        user_data = {
            "username": f"autotest_{timestamp}",
            "nickname": f"자동테스터{timestamp % 1000}",
            "email": f"autotest_{timestamp}@test.com",
            "password": "autotest123!"
        }
        
        # 회원가입
        try:
            response = requests.post(f"{BASE_URL}/api/auth/register", json=user_data)
            if response.status_code == 201:
                print(f"✅ 테스트 계정 생성: {user_data['username']}")
            else:
                print(f"❌ 회원가입 실패: {response.status_code}")
                return False
        except Exception as e:
            print(f"❌ 회원가입 오류: {e}")
            return False
        
        # 로그인
        try:
            login_data = {
                "username": user_data["username"],
                "password": user_data["password"]
            }
            response = requests.post(f"{BASE_URL}/api/auth/login", json=login_data)
            if response.status_code == 200:
                self.token = response.json()['access_token']
                print(f"✅ 로그인 성공: 토큰 획득")
                return True
            else:
                print(f"❌ 로그인 실패: {response.status_code}")
                return False
        except Exception as e:
            print(f"❌ 로그인 오류: {e}")
            return False
    
    def auto_create_progress_data(self):
        """진도 데이터 자동 생성"""
        print("\n📊 진도 데이터 자동 생성 중...")
        headers = {"Authorization": f"Bearer {self.token}"}
        
        for language in ['ksl']:
            try:
                response = requests.get(f"{BASE_URL}/api/progress/{language}", headers=headers)
                
                if response.status_code == 404:
                    # 진도 정보가 없으면, update API를 호출하여 새로 생성
                    print(f"   - {language.upper()} 진도 정보 없음. 새로 생성합니다.")
                    initial_data = {
                        "level": 1,
                        "completed_lessons": [],
                        "total_score": 0
                    }
                    # update API는 progress가 없으면 404를 반환하므로, reset API를 사용해 생성
                    reset_response = requests.post(f"{BASE_URL}/api/progress/{language}/reset", 
                                                   json={}, headers=headers)
                    if reset_response.status_code == 200:
                        print(f"✅ {language.upper()} 진도 데이터 생성 완료")
                    else:
                        print(f"❌ {language.upper()} 진도 데이터 생성 실패: {reset_response.text}")

                elif response.status_code == 200:
                    print(f"✅ {language.upper()} 진도 데이터 이미 존재")
                    
            except Exception as e:
                print(f"❌ {language.upper()} 진도 데이터 생성 중 오류: {e}")


    def test_progress_apis(self):
        """진도 관리 API 테스트"""
        print("\n" + "="*60)
        print("📊 진도 관리 API 테스트")
        print("="*60)
        
        headers = {"Authorization": f"Bearer {self.token}"}
        
        for language in ['ksl', 'asl']:
            # 1. 진도 조회
            try:
                response = requests.get(f"{BASE_URL}/api/progress/{language}", headers=headers)
                if response.status_code == 200:
                    progress = response.json()['progress']
                    self.log_result(f"GET /api/progress/{language}", True, 
                                  f"레벨: {progress['level']}, 점수: {progress['total_score']}")
                else:
                    self.log_result(f"GET /api/progress/{language}", False, 
                                  f"상태코드: {response.status_code}")
            except Exception as e:
                self.log_result(f"GET /api/progress/{language}", False, f"오류: {e}")
            
            # 2. 진도 업데이트
            try:
                update_data = {
                    "level": random.randint(2, 5),
                    "completed_lessons": [f"lesson_{i}" for i in range(1, 4)],
                    "total_score": random.randint(100, 500)
                }
                response = requests.post(f"{BASE_URL}/api/progress/{language}/update", 
                                       json=update_data, headers=headers)
                if response.status_code == 200:
                    self.log_result(f"POST /api/progress/{language}/update", True, 
                                  f"레벨 {update_data['level']}로 업데이트")
                else:
                    self.log_result(f"POST /api/progress/{language}/update", False, 
                                  f"상태코드: {response.status_code}")
            except Exception as e:
                self.log_result(f"POST /api/progress/{language}/update", False, f"오류: {e}")
            
            # 3. 진도 초기화
            try:
                response = requests.post(f"{BASE_URL}/api/progress/{language}/reset", 
                                       json={}, headers=headers)
                if response.status_code == 200:
                    self.log_result(f"POST /api/progress/{language}/reset", True, "초기화 완료")
                else:
                    self.log_result(f"POST /api/progress/{language}/reset", False, 
                                  f"상태코드: {response.status_code}")
            except Exception as e:
                self.log_result(f"POST /api/progress/{language}/reset", False, f"오류: {e}")
    
    def test_learning_apis(self):
        """학습 세션 API 테스트"""
        print("\n" + "="*60)
        print("🎓 학습 세션 API 테스트")
        print("="*60)
        
        headers = {"Authorization": f"Bearer {self.token}"}
        
        for language in ['ksl', 'asl']:
            # 1. 커리큘럼 조회
            try:
                response = requests.get(f"{BASE_URL}/api/learning/{language}/curriculum", headers=headers)
                if response.status_code == 200:
                    curriculum = response.json()
                    total_lessons = curriculum.get('total_lessons', 0)
                    self.log_result(f"GET /api/learning/{language}/curriculum", True, 
                                  f"{total_lessons}개 레슨 조회")
                else:
                    self.log_result(f"GET /api/learning/{language}/curriculum", False, 
                                  f"상태코드: {response.status_code}")
            except Exception as e:
                self.log_result(f"GET /api/learning/{language}/curriculum", False, f"오류: {e}")
            
            # 2. 학습 세션 시작
            session_id = None
            try:
                session_data = {
                    "level": random.randint(1, 3),
                    "lesson_type": random.choice(["alphabet", "words", "sentences"])
                }
                response = requests.post(f"{BASE_URL}/api/learning/{language}/session/start", 
                                       json=session_data, headers=headers)
                if response.status_code == 201:
                    session_id = response.json()['session']['id']
                    self.session_ids.append(session_id)
                    self.log_result(f"POST /api/learning/{language}/session/start", True, 
                                  f"세션 ID: {session_id}")
                else:
                    self.log_result(f"POST /api/learning/{language}/session/start", False, 
                                  f"상태코드: {response.status_code}")
            except Exception as e:
                self.log_result(f"POST /api/learning/{language}/session/start", False, f"오류: {e}")
            
            # 3. 퀴즈 결과 저장 (세션이 있는 경우)
            if session_id:
                try:
                    quiz_data = {
                        "session_id": session_id,
                        "level": 1,
                        "question_type": "recognition",
                        "question": f"Show the sign for: {'ㄱ' if language == 'ksl' else 'A'}",
                        "correct_answer": 'ㄱ' if language == 'ksl' else 'A',
                        "user_answer": 'ㄱ' if language == 'ksl' else 'A',
                        "is_correct": True,
                        "response_time": round(random.uniform(2.0, 8.0), 2),
                        "confidence_score": round(random.uniform(0.7, 0.98), 2)
                    }
                    response = requests.post(f"{BASE_URL}/api/learning/{language}/quiz", 
                                           json=quiz_data, headers=headers)
                    if response.status_code == 201:
                        self.log_result(f"POST /api/learning/{language}/quiz", True, 
                                      f"정답률: {quiz_data['confidence_score']:.2f}")
                    else:
                        self.log_result(f"POST /api/learning/{language}/quiz", False, 
                                      f"상태코드: {response.status_code}")
                except Exception as e:
                    self.log_result(f"POST /api/learning/{language}/quiz", False, f"오류: {e}")
            
            # 4. 학습 세션 종료 (세션이 있는 경우)
            if session_id:
                try:
                    end_data = {
                        "duration": random.randint(60, 300),
                        "total_attempts": random.randint(5, 20),
                        "correct_attempts": random.randint(3, 15),
                        "completed": True
                    }
                    response = requests.post(f"{BASE_URL}/api/learning/{language}/session/{session_id}/end", 
                                           json=end_data, headers=headers)
                    if response.status_code == 200:
                        accuracy = response.json()['session']['accuracy_rate']
                        self.log_result(f"POST /api/learning/{language}/session/{session_id}/end", True, 
                                      f"정확도: {accuracy}%")
                    else:
                        self.log_result(f"POST /api/learning/{language}/session/{session_id}/end", False, 
                                      f"상태코드: {response.status_code}")
                except Exception as e:
                    self.log_result(f"POST /api/learning/{language}/session/{session_id}/end", False, f"오류: {e}")
            
            # 5. 성취도 조회
            try:
                response = requests.get(f"{BASE_URL}/api/learning/{language}/achievements", headers=headers)
                if response.status_code == 200:
                    achievements = response.json()
                    total_achievements = achievements['statistics']['total_achievements']
                    avg_accuracy = achievements['statistics']['average_accuracy']
                    self.log_result(f"GET /api/learning/{language}/achievements", True, 
                                  f"성취도: {total_achievements}개, 평균: {avg_accuracy}%")
                else:
                    self.log_result(f"GET /api/learning/{language}/achievements", False, 
                                  f"상태코드: {response.status_code}")
            except Exception as e:
                self.log_result(f"GET /api/learning/{language}/achievements", False, f"오류: {e}")
    
    def test_quiz_apis(self):
        """퀴즈 시스템 API 테스트"""
        print("\n" + "="*60)
        print("🧩 퀴즈 시스템 API 테스트")
        print("="*60)
        
        headers = {"Authorization": f"Bearer {self.token}"}
        
        for language in ['ksl', 'asl']:
            # 1. 레벨 구조 조회
            try:
                response = requests.get(f"{BASE_URL}/api/quiz/{language}/levels", headers=headers)
                if response.status_code == 200:
                    levels = response.json()['levels']
                    self.log_result(f"GET /api/quiz/{language}/levels", True, 
                                  f"{len(levels)}개 레벨 조회")
                else:
                    self.log_result(f"GET /api/quiz/{language}/levels", False, 
                                  f"상태코드: {response.status_code}")
            except Exception as e:
                self.log_result(f"GET /api/quiz/{language}/levels", False, f"오류: {e}")
            
            # 2. 퀴즈 문제 생성
            try:
                generate_data = {
                    "level": random.randint(1, 4),
                    "mode": random.choice(["recognition", "translation"]),
                    "count": random.randint(3, 8)
                }
                response = requests.post(f"{BASE_URL}/api/quiz/{language}/generate", 
                                       json=generate_data, headers=headers)
                if response.status_code == 200:
                    questions = response.json()['questions']
                    self.log_result(f"POST /api/quiz/{language}/generate", True, 
                                  f"{len(questions)}개 문제 생성 ({generate_data['mode']})")
                else:
                    self.log_result(f"POST /api/quiz/{language}/generate", False, 
                                  f"상태코드: {response.status_code}")
            except Exception as e:
                self.log_result(f"POST /api/quiz/{language}/generate", False, f"오류: {e}")
            
            # 3. 퀴즈 스킵 (세션이 있는 경우)
            if self.session_ids:
                try:
                    skip_data = {
                        "session_id": self.session_ids[0],
                        "level": 1,
                        "question_type": "recognition",
                        "question": f"Show the sign for: {'ㄴ' if language == 'ksl' else 'B'}",
                        "correct_answer": 'ㄴ' if language == 'ksl' else 'B',
                        "response_time": 1.5
                    }
                    response = requests.post(f"{BASE_URL}/api/quiz/{language}/skip", 
                                           json=skip_data, headers=headers)
                    if response.status_code == 201:
                        self.log_result(f"POST /api/quiz/{language}/skip", True, "문제 스킵 완료")
                    else:
                        self.log_result(f"POST /api/quiz/{language}/skip", False, 
                                      f"상태코드: {response.status_code}")
                except Exception as e:
                    self.log_result(f"POST /api/quiz/{language}/skip", False, f"오류: {e}")
            
            # 4. 퀴즈 통계 조회
            try:
                response = requests.get(f"{BASE_URL}/api/quiz/{language}/statistics", headers=headers)
                if response.status_code == 200:
                    stats = response.json()['statistics']
                    total = stats['total_quizzes']
                    accuracy = stats['accuracy']
                    self.log_result(f"GET /api/quiz/{language}/statistics", True, 
                                  f"총 {total}개, 정확도: {accuracy}%")
                else:
                    self.log_result(f"GET /api/quiz/{language}/statistics", False, 
                                  f"상태코드: {response.status_code}")
            except Exception as e:
                self.log_result(f"GET /api/quiz/{language}/statistics", False, f"오류: {e}")
    
    def test_recognition_apis(self):
        """수어 인식 API 테스트"""
        print("\n" + "="*60)
        print("👋 수어 인식 API 테스트")
        print("="*60)
        
        headers = {"Authorization": f"Bearer {self.token}"}
        
        # 1. 인식 결과 저장
        recognition_samples = [
            {"language": "ksl", "text": "안녕하세요", "confidence": 0.92},
            {"language": "ksl", "text": "감사합니다", "confidence": 0.88},
            {"language": "asl", "text": "Hello", "confidence": 0.95},
            {"language": "asl", "text": "Thank you", "confidence": 0.90}
        ]
        
        for sample in recognition_samples:
            try:
                recognition_data = {
                    "language": sample["language"],
                    "recognized_text": sample["text"],
                    "confidence_score": sample["confidence"],
                    "session_duration": random.randint(30, 180)
                }
                response = requests.post(f"{BASE_URL}/api/recognition/save", 
                                       json=recognition_data, headers=headers)
                if response.status_code == 201:
                    self.log_result("POST /api/recognition/save", True, 
                                  f"{sample['language'].upper()}: {sample['text']}")
                else:
                    self.log_result("POST /api/recognition/save", False, 
                                  f"상태코드: {response.status_code}")
            except Exception as e:
                self.log_result("POST /api/recognition/save", False, f"오류: {e}")
        
        # 2. 인식 기록 조회 (API가 있다면)
        try:
            response = requests.get(f"{BASE_URL}/api/recognition/history", headers=headers)
            if response.status_code == 200:
                history = response.json()
                count = len(history) if isinstance(history, list) else history.get('count', 0)
                self.log_result("GET /api/recognition/history", True, f"{count}개 기록 조회")
            elif response.status_code == 404:
                self.log_result("GET /api/recognition/history", True, "API 미구현 (정상)")
            else:
                self.log_result("GET /api/recognition/history", False, 
                              f"상태코드: {response.status_code}")
        except Exception as e:
            self.log_result("GET /api/recognition/history", False, f"오류: {e}")
    
    def print_summary(self):
        """테스트 결과 요약"""
        print("\n" + "="*60)
        print("📋 테스트 결과 요약")
        print("="*60)
        
        total_tests = len(self.test_results)
        successful_tests = sum(1 for result in self.test_results if result['success'])
        failed_tests = total_tests - successful_tests
        
        print(f"📊 총 테스트: {total_tests}개")
        print(f"✅ 성공: {successful_tests}개")
        print(f"❌ 실패: {failed_tests}개")
        print(f"📈 성공률: {(successful_tests/total_tests*100):.1f}%")
        
        if failed_tests > 0:
            print(f"\n❌ 실패한 테스트:")
            for result in self.test_results:
                if not result['success']:
                    print(f"   • {result['api']}: {result['message']}")
        
        print(f"\n🎉 자동 테스트 완료!")
    
    def run_all_tests(self):
        """모든 테스트 자동 실행"""
        print("🚀 SignTalk 자동 완전 테스트 시작")
        print(f"📅 {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"🌐 서버: {BASE_URL}")
        
        start_time = time.time()
        
        # 1. 테스트 환경 설정
        if not self.setup_test_user():
            print("❌ 테스트 환경 설정 실패")
            return
        
        # 2. 진도 데이터 자동 생성
        self.auto_create_progress_data()
        
        # 3. 모든 API 테스트 실행
        self.test_progress_apis()
        self.test_learning_apis()
        self.test_quiz_apis()
        self.test_recognition_apis()
        
        # 4. 결과 요약
        end_time = time.time()
        duration = end_time - start_time
        
        self.print_summary()
        print(f"⏱️  총 소요 시간: {duration:.2f}초")

if __name__ == "__main__":
    tester = AutoCompleteTest()
    tester.run_all_tests()
