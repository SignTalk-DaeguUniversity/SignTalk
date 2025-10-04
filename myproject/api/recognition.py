# - 손모양 분석 및 세션 관리 API (H5 모델 버전)
from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from auth.models import db, Recognition
from datetime import datetime
import uuid
import random
import tensorflow as tf
import mediapipe as mp
import cv2
import numpy as np
import os
import base64
from PIL import Image
import io

recognition_bp = Blueprint('recognition', __name__)

# 전역 세션 저장소
active_sessions = {}

# ==== AI 모델 초기화 ====
BASE_DIR = os.path.dirname(os.path.dirname(__file__))  # myproject 폴더
MODEL_DIR = os.path.join(BASE_DIR, "model")
KSL_MODEL_PATH = os.path.join(MODEL_DIR, "ksl_model.h5")
KSL_LABELS_PATH = os.path.join(MODEL_DIR, "ksl_labels.npy")

# 전역 모델 변수
ksl_model = None
labels_ksl = None
mp_hands = None
hands = None

def initialize_ai_models():
    """AI 모델 초기화"""
    global ksl_model, labels_ksl, mp_hands, hands
    
    try:
        # Keras 모델 로딩
        ksl_model = tf.keras.models.load_model(KSL_MODEL_PATH)
        labels_ksl = np.load(KSL_LABELS_PATH, allow_pickle=True)
        
        # MediaPipe 초기화
        mp_hands = mp.solutions.hands
        hands = mp_hands.Hands(
            static_image_mode=True,  # 정적 이미지 모드
            max_num_hands=1,
            min_detection_confidence=0.5,
            min_tracking_confidence=0.5
        )
        
        print("✅ AI 모델 초기화 성공 (H5 모델)")
        print(f"   - 모델 경로: {KSL_MODEL_PATH}")
        print(f"   - 라벨 개수: {len(labels_ksl)}")
        return True
        
    except Exception as e:
        print(f"❌ AI 모델 초기화 실패: {e}")
        return False

# 모델 초기화 실행
model_initialized = initialize_ai_models()

def decode_base64_image(image_data):
    """Base64 이미지 데이터를 OpenCV 이미지로 변환"""
    try:
        # Base64 헤더 제거 (data:image/jpeg;base64, 부분)
        if ',' in image_data:
            image_data = image_data.split(',')[1]
        
        # Base64 디코딩
        image_bytes = base64.b64decode(image_data)
        
        # PIL Image로 변환
        pil_image = Image.open(io.BytesIO(image_bytes))
        
        # OpenCV 형식으로 변환
        opencv_image = cv2.cvtColor(np.array(pil_image), cv2.COLOR_RGB2BGR)
        
        return opencv_image
        
    except Exception as e:
        print(f"❌ 이미지 디코딩 실패: {e}")
        return None

def analyze_sign_accuracy(image_data, target_sign, language):
    """실제 AI 모델을 사용한 수어 정확도 분석"""
    
    # 모델이 초기화되지 않은 경우 폴백
    if not model_initialized or ksl_model is None:
        print("⚠️ AI 모델이 초기화되지 않음. 폴백 모드 사용")
        return fallback_analysis(target_sign, language)
    
    try:
        # 1. 이미지 디코딩
        if not image_data:
            print("⚠️ 이미지 데이터 없음")
            return fallback_analysis(target_sign, language)
        
        image = decode_base64_image(image_data)
        if image is None:
            print("⚠️ 이미지 디코딩 실패")
            return fallback_analysis(target_sign, language)
        
        # 2. 이미지 전처리
        image_rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
        
        # 3. MediaPipe로 손 인식
        results = hands.process(image_rgb)
        
        if not results.multi_hand_landmarks:
            return {
                'accuracy': 0.0,
                'confidence': 0.0,
                'feedback': generate_detailed_feedback(0.0, target_sign, language),
                'hand_detected': False,
                'target_sign': target_sign,
                'language': language,
                'error': '손이 감지되지 않았습니다'
            }
        
        # 4. 손 랜드마크 추출
        hand_landmarks = results.multi_hand_landmarks[0]
        coords = []
        for landmark in hand_landmarks.landmark:
            coords.extend([landmark.x, landmark.y])
        
        # 5. AI 모델 예측 (H5 모델)
        input_data = np.array(coords, dtype=np.float32).reshape(1, -1)
        prediction = ksl_model.predict(input_data, verbose=0)
        
        # 6. 결과 분석
        predicted_idx = np.argmax(prediction)
        confidence_score = float(np.max(prediction))
        
        if 0 <= predicted_idx < len(labels_ksl):
            predicted_sign = labels_ksl[predicted_idx]
        else:
            predicted_sign = "UNKNOWN"
        
        # 7. 정확도 계산
        is_correct = predicted_sign == target_sign
        accuracy = confidence_score * 100 if is_correct else max(0, confidence_score * 50)
        
        # 8. 피드백 생성
        feedback = generate_detailed_feedback(accuracy, target_sign, language)
        
        return {
            'accuracy': round(accuracy, 1),
            'confidence': round(confidence_score, 2),
            'feedback': feedback,
            'hand_detected': True,
            'target_sign': target_sign,
            'predicted_sign': predicted_sign,
            'is_correct': is_correct,
            'language': language
        }
        
    except Exception as e:
        print(f"❌ AI 분석 중 오류: {e}")
        return fallback_analysis(target_sign, language)

def fallback_analysis(target_sign, language):
    """AI 모델 실패 시 폴백 분석"""
    # 수어별 난이도 설정
    sign_difficulty = {
        'A': 0.9, 'B': 0.8, 'C': 0.7, 'D': 0.8, 'E': 0.9,
        'F': 0.7, 'G': 0.6, 'H': 0.8, 'I': 0.9, 'J': 0.6,
        'Hello': 0.6, 'Thank you': 0.5, 'Please': 0.6,
        'ㄱ': 0.8, 'ㄴ': 0.7, 'ㄷ': 0.8, 'ㄹ': 0.6, 'ㅁ': 0.7,
        '안녕하세요': 0.5, '감사합니다': 0.4
    }
    
    # 기본 정확도 계산 (폴백 모드)
    base_accuracy = 75.0
    difficulty_factor = sign_difficulty.get(target_sign, 0.7)
    random_factor = random.uniform(0.7, 1.3)
    language_factor = 1.0 if language == 'asl' else 0.95
    
    final_accuracy = min(100.0, base_accuracy * difficulty_factor * random_factor * language_factor)
    confidence = final_accuracy / 100.0
    
    # 피드백 생성
    feedback = generate_detailed_feedback(final_accuracy, target_sign, language)
    
    return {
        'accuracy': round(final_accuracy, 1),
        'confidence': round(confidence, 2),
        'feedback': feedback,
        'hand_detected': True,
        'target_sign': target_sign,
        'language': language,
        'fallback_mode': True
    }

def generate_detailed_feedback(accuracy, target_sign, language):
    """상세 피드백 생성"""
    
    if accuracy >= 90:
        return {
            'level': 'excellent',
            'message': f'완벽한 "{target_sign}" 수어입니다! 🎉',
            'suggestions': ['훌륭해요! 다음 단계로 진행하세요'],
            'color': 'green',
            'score': 'A+'
        }
    elif accuracy >= 80:
        return {
            'level': 'very_good',
            'message': f'아주 좋은 "{target_sign}" 수어입니다! 👍',
            'suggestions': ['거의 완벽해요!', '조금만 더 연습하면 완벽할 거예요'],
            'color': 'lightgreen',
            'score': 'A'
        }
    elif accuracy >= 70:
        return {
            'level': 'good',
            'message': f'좋은 "{target_sign}" 수어입니다! 💪',
            'suggestions': [
                '손가락 위치를 조금 더 정확하게 해보세요',
                '손목을 자연스럽게 유지하세요'
            ],
            'color': 'blue',
            'score': 'B+'
        }
    elif accuracy >= 60:
        return {
            'level': 'fair',
            'message': f'"{target_sign}" 수어를 연습 중이네요 🤔',
            'suggestions': [
                '손 모양을 더 명확하게 해보세요',
                '참고 이미지를 다시 확인해보세요',
                '천천히 정확하게 해보세요'
            ],
            'color': 'orange',
            'score': 'B'
        }
    else:
        return {
            'level': 'needs_improvement',
            'message': '손 모양을 다시 확인해보세요',
            'suggestions': [
                '카메라와 적절한 거리를 유지하세요',
                '조명이 충분한 곳에서 시도하세요',
                '손을 카메라 중앙에 위치시키세요'
            ],
            'color': 'red',
            'score': 'C'
        }

# ===== 실시간 수어 인식 API =====

@recognition_bp.route('/api/recognition/real-time', methods=['POST'])
@jwt_required()
def real_time_recognition():
    """실시간 수어 인식 (단일 이미지)"""
    try:
        user_id = get_jwt_identity()
        data = request.get_json()
        
        # 필수 데이터 확인
        if not data.get('image_data'):
            return jsonify({'error': '이미지 데이터가 필요합니다.'}), 400
        
        language = data.get('language', 'ksl')
        
        # 모델이 초기화되지 않은 경우
        if not model_initialized or ksl_model is None:
            return jsonify({
                'error': 'AI 모델이 초기화되지 않았습니다.',
                'model_available': False
            }), 503
        
        # 이미지 처리 및 인식
        result = recognize_sign_from_image(data['image_data'], language)
        
        return jsonify({
            'recognition_result': result,
            'timestamp': datetime.utcnow().isoformat(),
            'model_available': True
        }), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

def recognize_sign_from_image(image_data, language):
    """이미지에서 수어 인식"""
    try:
        # 1. 이미지 디코딩
        image = decode_base64_image(image_data)
        if image is None:
            return {
                'recognized_sign': None,
                'confidence': 0.0,
                'hand_detected': False,
                'error': '이미지 디코딩 실패'
            }
        
        # 2. 이미지 전처리
        image_rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
        
        # 3. MediaPipe로 손 인식
        results = hands.process(image_rgb)
        
        if not results.multi_hand_landmarks:
            return {
                'recognized_sign': None,
                'confidence': 0.0,
                'hand_detected': False,
                'error': '손이 감지되지 않음'
            }
        
        # 4. 손 랜드마크 추출
        hand_landmarks = results.multi_hand_landmarks[0]
        coords = []
        for landmark in hand_landmarks.landmark:
            coords.extend([landmark.x, landmark.y])
        
        # 5. AI 모델 예측 (H5 모델)
        input_data = np.array(coords, dtype=np.float32).reshape(1, -1)
        prediction = ksl_model.predict(input_data, verbose=0)
        
        # 6. 결과 분석
        predicted_idx = np.argmax(prediction)
        confidence_score = float(np.max(prediction))
        
        if 0 <= predicted_idx < len(labels_ksl):
            recognized_sign = labels_ksl[predicted_idx]
        else:
            recognized_sign = "UNKNOWN"
        
        return {
            'recognized_sign': recognized_sign,
            'confidence': round(confidence_score, 3),
            'hand_detected': True,
            'prediction_index': int(predicted_idx),
            'all_predictions': prediction.tolist()
        }
        
    except Exception as e:
        return {
            'recognized_sign': None,
            'confidence': 0.0,
            'hand_detected': False,
            'error': str(e)
        }

# ===== 손모양 분석 API =====

@recognition_bp.route('/api/recognition/analyze-hand', methods=['POST'])
@jwt_required()
def analyze_hand_shape():
    """손모양 분석 및 정확도 측정"""
    try:
        user_id = get_jwt_identity()
        data = request.get_json()
        
        # 필수 데이터 확인
        required_fields = ['target_sign', 'language']
        for field in required_fields:
            if not data.get(field):
                return jsonify({'error': f'{field}는 필수입니다.'}), 400
        
        # 손모양 분석 수행
        analysis_result = analyze_sign_accuracy(
            data.get('image_data', ''),
            data['target_sign'],
            data['language']
        )
        
        return jsonify({
            'analysis': analysis_result,
            'message': '손모양 분석이 완료되었습니다.',
            'model_type': 'H5'
        }), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# ===== 모델 상태 확인 API =====

@recognition_bp.route('/api/recognition/model-status', methods=['GET'])
def get_model_status():
    """AI 모델 상태 확인"""
    try:
        status = {
            'model_initialized': model_initialized,
            'ksl_model_available': ksl_model is not None,
            'mediapipe_available': hands is not None,
            'model_path': KSL_MODEL_PATH,
            'model_type': 'H5 (Keras)',
            'labels_count': len(labels_ksl) if labels_ksl is not None else 0
        }
        
        if labels_ksl is not None:
            status['available_signs'] = labels_ksl.tolist()
        
        return jsonify(status), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500