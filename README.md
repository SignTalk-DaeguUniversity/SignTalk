# SignTalk
[2025-2] 
source signtalk_env/bin/activate

# requirements.txt 설치 
# 추가적인게 생길때마다 업데이트 
pip install -r requirements.txt


# API endpoints

// Flutter HTTP 요청 예시
final baseUrl = 'http://localhost:5002';

// 1. 회원가입
POST $baseUrl/api/auth/register
Body: {"username": "user", "email": "email", "password": "pass"}

// 2. 로그인  
POST $baseUrl/api/auth/login
Body: {"username": "user", "password": "pass"}

// 3. 프로필 조회
GET $baseUrl/api/auth/profile
Headers: {"Authorization": "Bearer $token"}

// 4. 진도 조회
GET $baseUrl/api/progress/asl (또는 ksl)
Headers: {"Authorization": "Bearer $token"}

// 5. 진도 업데이트
POST $baseUrl/api/progress/asl/update
Headers: {"Authorization": "Bearer $token"}
Body: {"level": 2, "total_score": 100}