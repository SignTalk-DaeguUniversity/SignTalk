from flask import Flask, Response, jsonify, request
import cv2
import mediapipe as mp
import numpy as np
import time
import tensorflow as tf
import os
from datetime import datetime
from flask_cors import CORS
from flask_jwt_extended import JWTManager
from config import Config
from auth.models import db
from auth.routes import auth_bp, bcrypt
from api.progress import progress_bp
from api.learning import learning_bp
from api.recognition import recognition_bp
from api.quiz import quiz_bp
from api.jamo_decompose import jamo_decompose_bp
from api.jamo_compose import jamo_compose_bp

app = Flask(__name__)
app.config.from_object(Config)

# 확장 초기화
db.init_app(app)
bcrypt.init_app(app)
jwt = JWTManager(app)
CORS(app)  # Flutter와 통신을 위한 CORS 설정


# JWT 블랙리스트 import
from auth.routes import blacklisted_tokens

# JWT 토큰 블랙리스트 체크 함수
@jwt.token_in_blocklist_loader
def check_if_token_revoked(jwt_header, jwt_payload):
    """토큰이 블랙리스트에 있는지 확인"""
    jti = jwt_payload['jti']
    return jti in blacklisted_tokens
    
# 블루프린트 등록
app.register_blueprint(auth_bp)
app.register_blueprint(progress_bp)
app.register_blueprint(learning_bp)
app.register_blueprint(recognition_bp)
app.register_blueprint(quiz_bp)
app.register_blueprint(jamo_decompose_bp)
app.register_blueprint(jamo_compose_bp)

# ==== 경로 설정 ====
BASE_DIR = os.path.dirname(__file__)
MODEL_DIR = os.path.join(BASE_DIR, "model")

KSL_MODEL_PATH = os.path.join(MODEL_DIR, "ksl_model.h5")
KSL_LABELS_PATH = os.path.join(MODEL_DIR, "ksl_labels.npy")

# ==== 모델 로딩 (H5 모델) ====
try:
    ksl_model = tf.keras.models.load_model(KSL_MODEL_PATH)
    labels_ksl = np.load(KSL_LABELS_PATH, allow_pickle=True)

    print("✅ KSL H5 모델 및 라벨 로딩 성공")
    print(f"   - 모델 경로: {KSL_MODEL_PATH}")
    print(f"   - 라벨 개수: {len(labels_ksl)}")
except Exception as e:
    print(f"❌ 모델 로딩 실패: {e}")
    print("📱 API 서버만 실행됩니다 (수어 인식 기능 비활성화)")
    ksl_model = None

# ==== Mediapipe 설정 ====
mp_hands = mp.solutions.hands
hands = mp_hands.Hands(
    static_image_mode=False,
    max_num_hands=1,
    min_detection_confidence=0.5,
    min_tracking_confidence=0.5)
mp_draw = mp.solutions.drawing_utils

# ==== 인식 결과 저장 ====
recognized_string = {"ksl": ""}
latest_char = {"ksl": ""}
last_recognized_char = {"ksl": ""}  # 이전 인식 문자
last_recognized_time = {"ksl": 0}  # 이전 인식 시간

# ==== 쌍자음 매핑 ====
DOUBLE_CONSONANT_MAP = {
    'ㄱ': 'ㄲ',
    'ㄷ': 'ㄸ',
    'ㅂ': 'ㅃ',
    'ㅅ': 'ㅆ',
    'ㅈ': 'ㅉ'
}



# ==== 현재 프레임 저장용 전역 변수 ====
current_frame_cache = {}  # {lang_key: frame}

# ==== 공통 영상 스트리밍 (H5 모델용) ====
def generate_frames(model, labels, lang_key, camera_device=0):
    global current_frame_cache
    # 카메라 열기 (macOS 호환성 개선)
    print(f"📷 카메라 {camera_device}번 열기 시도...")
    cap = cv2.VideoCapture(camera_device)
    
    if not cap.isOpened():
        print("❌ 카메라 열기 실패")
        print("   - 다른 앱이 카메라를 사용 중인지 확인하세요")
        print("   - 시스템 설정 > 개인정보 보호 > 카메라 권한을 확인하세요")
        return
    
    print(f"✅ 카메라 {camera_device}번 열기 성공")
    
    # 기본 설정만 적용 (macOS 호환성)
    cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
    cap.set(cv2.CAP_PROP_FPS, 30)
    cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)
    
    actual_width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    actual_height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    actual_fps = cap.get(cv2.CAP_PROP_FPS)
    
    print(f"📷 카메라 설정 완료: {actual_width}x{actual_height} @ {actual_fps}fps")

    last_prediction_time = 0
    prediction_interval = 0.15  # 0.15초마다 인식 (빠른 응답)
    prev_idx = -1
    consecutive_same = 0  # 연속 같은 결과 카운트
    last_predicted_char = ""
    confidence_threshold = 0.6  # 신뢰도 임계값 상향
    
    # MediaPipe 항상 활성화 (성능 최적화)
    print("🚀 MediaPipe 항상 활성화 모드")

    try:
        while True:
            ret, frame = cap.read()
            if not ret:
                break

            if len(frame.shape) == 2 or frame.shape[2] == 1:
                frame = cv2.cvtColor(frame, cv2.COLOR_GRAY2BGR)

            # 이미지 전처리 최적화
            image = cv2.flip(frame, 1)  # 좌우 반전
            rgb_image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
            current_time = time.time()
            
            # 현재 프레임을 캐시에 저장 (API에서 사용)
            current_frame_cache[lang_key] = image.copy()

            # MediaPipe 항상 활성화
            result = hands.process(rgb_image)

            if result.multi_hand_landmarks:
                for hand_landmarks in result.multi_hand_landmarks:
                    # 손 랜드마크 그리기
                    mp_draw.draw_landmarks(image, hand_landmarks, mp_hands.HAND_CONNECTIONS)

                    if current_time - last_prediction_time >= prediction_interval:
                        coords = [v for lm in hand_landmarks.landmark for v in (lm.x, lm.y)]
                        input_data = np.array(coords, dtype=np.float32).reshape(1, -1)
                        prediction = model.predict(input_data, verbose=0)
                        idx = np.argmax(prediction)
                        confidence = float(np.max(prediction))

                        # 신뢰도 임계값
                        if 0 <= idx < len(labels) and confidence > confidence_threshold:
                            predicted_char = labels[idx]
                            
                            # 즉시 업데이트 (빠른 응답)
                            latest_char[lang_key] = predicted_char
                            current_time_sec = time.time()
                            time_diff = current_time_sec - last_recognized_time.get(lang_key, 0)
                            
                            # 쌍자음 처리 로직
                            if (predicted_char in DOUBLE_CONSONANT_MAP and 
                                predicted_char == last_recognized_char.get(lang_key, '') and 
                                0.5 < time_diff < 3.0):
                                
                                # 쌍자음으로 변환
                                double_char = DOUBLE_CONSONANT_MAP[predicted_char]
                                latest_char[lang_key] = double_char
                                print(f"🎯🎯 쌍자음: {predicted_char} + {predicted_char} → {double_char}")
                                
                                # 초기화
                                last_recognized_char[lang_key] = ""
                                last_recognized_time[lang_key] = 0
                            else:
                                # 일반 인식
                                print(f"🎯 {predicted_char} 인식 (신뢰도: {confidence:.3f})")
                                
                                # 쌍자음 대기 정보 저장
                                last_recognized_char[lang_key] = predicted_char
                                last_recognized_time[lang_key] = current_time_sec
                        else:
                            latest_char[lang_key] = ""
                            consecutive_same = 0
                            last_predicted_char = ""

                        prev_idx = idx
                        last_prediction_time = current_time
            else:
                # 손이 감지되지 않으면 초기화
                latest_char[lang_key] = ""
                consecutive_same = 0
                last_predicted_char = ""
                # 쌍자음 타이머는 유지 (손을 떼도 3초 이내면 쌍자음 가능)

            # 디버깅 정보 표시
            hands_detected = "YES" if result.multi_hand_landmarks else "NO"
            current_char = latest_char[lang_key] if latest_char[lang_key] else "None"
            
            # 상단: 현재 인식 결과
            cv2.putText(image, f"Current: {current_char}", (10, 30),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
            
            # 중간: 손 감지 상태
            cv2.putText(image, f"Hands: {hands_detected}", (10, 60),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 0, 0), 2)
            
            # 하단: 누적 문자열
            accumulated = recognized_string[lang_key][:10]  # 처음 10글자만
            cv2.putText(image, f"Text: {accumulated}", (10, 90),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 0, 255), 2)

            # JPEG 압축 최적화 (전송 속도 향상, 인식 정확도는 유지)
            encode_param = [int(cv2.IMWRITE_JPEG_QUALITY), 75]
            ret, buffer = cv2.imencode('.jpg', image, encode_param)
            frame = buffer.tobytes()

            yield (b'--frame\r\n'
                   b'Content-Type: image/jpeg\r\n\r\n' + frame + b'\r\n')

    except GeneratorExit:
        print("🛑 스트리밍 중단 감지: 클라이언트 연결 종료됨")
    finally:
        cap.release()
        print("✅ 카메라 자원 해제 완료")

# ==== 라우팅 ====
@app.route('/')
def index():
    """서버 상태 확인 페이지"""
    return jsonify({
        'server': 'SignTalk API Server',
        'status': 'running',
        'version': '1.0.0',
        'endpoints': {
            'video_stream': '/video_feed_ksl',
            'recognition': '/api/recognition/current/<lang>',
            'health': '/api/auth/health',
            'progress': '/api/progress/<lang>'
        }
    })

@app.route('/video_feed_ksl')
def video_feed_ksl():
    if ksl_model is None:
        return jsonify({'error': 'KSL 모델이 로드되지 않았습니다.'}), 503
    
    # 클라이언트 정보 확인 (에뮬레이터 vs 실제 기기)
    client_ip = request.environ.get('HTTP_X_FORWARDED_FOR', request.environ.get('REMOTE_ADDR', ''))
    user_agent = request.headers.get('User-Agent', '')
    remote_addr = request.environ.get('REMOTE_ADDR', '')
    
    print("="*60)
    print(f"🔍 비디오 스트림 요청 상세:")
    print(f"   - HTTP_X_FORWARDED_FOR: {request.environ.get('HTTP_X_FORWARDED_FOR', 'None')}")
    print(f"   - REMOTE_ADDR: {remote_addr}")
    print(f"   - Client IP (최종): {client_ip}")
    print(f"   - User-Agent: {user_agent}")
    print(f"   - Request URL: {request.url}")
    print("="*60)
    
    # 에뮬레이터 감지 (더 강력한 조건)
    is_emulator = (
        '10.0.2.2' in str(client_ip) or
        '10.0.2.2' in str(remote_addr) or
        '127.0.0.1' in str(client_ip) or
        'localhost' in str(client_ip) or
        '::1' in str(client_ip)  # IPv6 localhost
    )
    
    # 카메라 선택
    if is_emulator:
        # 에뮬레이터: 노트북 내장 카메라 찾기
        # macOS Continuity Camera 문제 회피: 1번 카메라 시도
        camera_device = 0  # 0번 카메라 사용 (유일한 카메라)
        print("✅ 에뮬레이터 감지 → 카메라 0번 사용")
        print("   (iPhone Continuity Camera든 노트북 카메라든 0번만 존재)")
    else:
        camera_device = 0  # 실제 기기 전면 카메라
        print("✅ 실제 기기 감지 → 기기 전면 카메라 (0번) 사용")
    
    print(f"📷 최종 선택된 카메라: {camera_device}번")
    print("="*60)
    
    return Response(generate_frames(ksl_model, labels_ksl, "ksl", camera_device),
                    mimetype='multipart/x-mixed-replace; boundary=frame')

@app.route('/api/recognition/current/<lang>')
@app.route('/get_string/<lang>')  # 하위 호환성
def get_current_recognition(lang):
    """현재 인식 결과 반환 (통합 API)"""
    current_char = latest_char.get(lang, '')
    accumulated_string = recognized_string.get(lang, '')
    
    # 디버깅 정보
    print(f"📱 인식 결과 요청: {lang} - Current: '{current_char}', String: '{accumulated_string}'")
    
    return jsonify({
        # 새 API 형식
        'current_character': current_char,
        'accumulated_string': accumulated_string,
        # 기존 API 형식 (하위 호환성)
        'current': current_char,
        'string': accumulated_string,
        # 추가 정보
        'timestamp': time.time(),
        'language': lang,
        'has_current': bool(current_char and current_char.strip())
    })

@app.route('/camera_info')
def camera_info():
    """현재 카메라 설정 정보 반환"""
    try:
        # 클라이언트 정보
        client_ip = request.environ.get('HTTP_X_FORWARDED_FOR', request.environ.get('REMOTE_ADDR', ''))
        user_agent = request.headers.get('User-Agent', '')
        
        # 에뮬레이터 감지
        is_emulator = (
            '10.0.2.2' in client_ip or
            '127.0.0.1' in client_ip or
            'localhost' in client_ip
        )
        
        return jsonify({
            'client_ip': client_ip,
            'user_agent': user_agent,
            'is_emulator': is_emulator,
            'camera_device': 0,  # 항상 0번 카메라 사용
            'camera_type': 'laptop_webcam' if is_emulator else 'device_front_camera',
            'platform': {
                'system': os.name,
                'platform': __import__('platform').system()
            }
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/auth/health')
def health_check():
    """서버 상태 확인 (Flutter 앱용)"""
    return jsonify({
        'status': 'healthy',
        'server': 'SignTalk API Server',
        'version': '1.0.0',
        'timestamp': datetime.utcnow().isoformat()
    }), 200

@app.route('/add_char/<lang>')
def add_char(lang):
    if latest_char[lang] and latest_char[lang] not in ["ERR:IDX", "ERR:DIM", ""]:
        recognized_string[lang] += latest_char[lang]
        print(f"✅ 문자 추가: {latest_char[lang]} → {recognized_string[lang]}")
    return jsonify({
        'success': True, 
        'current': latest_char[lang],
        'accumulated': recognized_string[lang]
    })



@app.route('/remove_char/<lang>')
def remove_char(lang):
    if recognized_string[lang]:
        recognized_string[lang] = recognized_string[lang][:-1]
    return jsonify({'success': True})

@app.route('/clear_string/<lang>')
def clear_string(lang):
    recognized_string[lang] = ""
    return jsonify({'success': True})

@app.route('/upload_image/<lang>', methods=['POST'])
def upload_image(lang):
    """디바이스 카메라에서 촬영한 이미지를 받아서 수어 인식 처리"""
    try:
        if 'image' not in request.files:
            return jsonify({'error': 'No image file provided'}), 400
        
        file = request.files['image']
        if file.filename == '':
            return jsonify({'error': 'No image file selected'}), 400
        
        # 이미지 파일을 numpy 배열로 변환
        import numpy as np
        from PIL import Image
        import io
        
        # 파일을 메모리에서 읽기
        image_bytes = file.read()
        image = Image.open(io.BytesIO(image_bytes))
        
        # OpenCV 형식으로 변환
        image_array = np.array(image)
        if len(image_array.shape) == 3 and image_array.shape[2] == 3:
            # RGB to BGR 변환 (OpenCV는 BGR 사용)
            image_array = cv2.cvtColor(image_array, cv2.COLOR_RGB2BGR)
        
        # 수어 인식 처리
        result = process_uploaded_image(image_array, lang)
        
        return jsonify({
            'success': True,
            'recognized_character': result.get('character', ''),
            'confidence': result.get('confidence', 0.0)
        })
        
    except Exception as e:
        print(f"❌ 이미지 업로드 처리 실패: {e}")
        return jsonify({'error': str(e)}), 500

def process_uploaded_image(image, lang):
    """업로드된 이미지에서 수어 인식 처리"""
    try:
        # 언어별 모델 선택
        if lang == 'ksl':
            model = ksl_model
            labels = labels_ksl
        else:
            # ASL 모델이 있다면 여기서 처리
            return {'character': '', 'confidence': 0.0}
        
        if model is None:
            return {'character': '', 'confidence': 0.0}
        
        # 이미지 크기 조정
        image = cv2.resize(image, (320, 240))
        rgb_image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
        
        # MediaPipe로 손 랜드마크 추출
        result = hands.process(rgb_image)
        
        if result.multi_hand_landmarks:
            for hand_landmarks in result.multi_hand_landmarks:
                # 좌표 추출
                coords = [v for lm in hand_landmarks.landmark for v in (lm.x, lm.y)]
                input_data = np.array(coords, dtype=np.float32).reshape(1, -1)
                
                # 모델 추론 (H5 모델)
                prediction = model.predict(input_data, verbose=0)
                
                idx = np.argmax(prediction)
                confidence = float(np.max(prediction))
                
                if 0 <= idx < len(labels):
                    character = labels[idx]
                    # 전역 변수 업데이트
                    latest_char[lang] = character
                    return {'character': character, 'confidence': confidence}
        
        return {'character': '', 'confidence': 0.0}
        
    except Exception as e:
        print(f"❌ 이미지 처리 실패: {e}")
        return {'character': '', 'confidence': 0.0}



if __name__ == '__main__':
    # 실제 기기에서 접근 가능하도록 0.0.0.0으로 바인딩
    app.run(debug=True, host='0.0.0.0', port=5002)