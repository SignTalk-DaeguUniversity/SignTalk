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

# ==== 쌍자음/복합모음 정의 ====
# 시퀀스 모델 사용 (연속 동작 필요)
SEQUENCE_SIGNS = ['ㄲ', 'ㄸ', 'ㅃ', 'ㅆ', 'ㅉ', 'ㅘ', 'ㅙ', 'ㅝ', 'ㅞ']
# ㅚ, ㅟ, ㅢ는 정적 모델로 인식 (한 번에 가능)

DOUBLE_CONSONANT_MAP = {
    'ㄱ': 'ㄲ',
    'ㄷ': 'ㄸ',
    'ㅂ': 'ㅃ',
    'ㅅ': 'ㅆ',
    'ㅈ': 'ㅉ'
}

# ==== AI 모델 초기화 ====
BASE_DIR = os.path.dirname(os.path.dirname(__file__))  # myproject 폴더
MODEL_DIR = os.path.join(BASE_DIR, "model")

# 정적 모델 (기본 자음/모음)
KSL_MODEL_PATH = os.path.join(MODEL_DIR, "ksl_model.h5")
KSL_LABELS_PATH = os.path.join(MODEL_DIR, "ksl_labels.npy")
KSL_NORM_MEAN_PATH = os.path.join(MODEL_DIR, "ksl_norm_mean.npy")
KSL_NORM_STD_PATH = os.path.join(MODEL_DIR, "ksl_norm_std.npy")

# 시퀀스 모델 (쌍자음/복합모음)
KSL_SEQ_MODEL_PATH = os.path.join(MODEL_DIR, "ksl_model_sequence.h5")
KSL_SEQ_LABELS_PATH = os.path.join(MODEL_DIR, "ksl_labels_sequence.npy")
KSL_SEQ_CONFIG_PATH = os.path.join(MODEL_DIR, "ksl_sequence_config.npy")
KSL_SEQ_NORM_MEAN_PATH = os.path.join(MODEL_DIR, "ksl_seq_norm_mean.npy")
KSL_SEQ_NORM_STD_PATH = os.path.join(MODEL_DIR, "ksl_seq_norm_std.npy")

# 전역 모델 변수
ksl_model = None  # 정적 모델
labels_ksl = None  # 정적 라벨
ksl_norm_mean = None  # 정적 모델 정규화 평균
ksl_norm_std = None  # 정적 모델 정규화 표준편차
ksl_seq_model = None  # 시퀀스 모델
labels_ksl_seq = None  # 시퀀스 라벨
seq_max_timesteps = None  # 시퀀스 최대 프레임 수
seq_norm_mean = None  # 시퀀스 정규화 평균
seq_norm_std = None  # 시퀀스 정규화 표준편차
mp_hands = None
hands = None

# 시퀀스 버퍼 (사용자별)
from collections import deque
sequence_buffers = {}  # {user_id: deque}

def initialize_ai_models():
    """AI 모델 초기화 (하이브리드: 정적 + 시퀀스)"""
    global ksl_model, labels_ksl, ksl_norm_mean, ksl_norm_std, ksl_seq_model, labels_ksl_seq, seq_max_timesteps, seq_norm_mean, seq_norm_std, mp_hands, hands
    
    try:
        # 1. 정적 모델 로딩 (기본 자음/모음)
        ksl_model = tf.keras.models.load_model(KSL_MODEL_PATH)
        labels_ksl = np.load(KSL_LABELS_PATH, allow_pickle=True)
        
        # 정규화 통계 로드 (정적 모델용)
        if os.path.exists(KSL_NORM_MEAN_PATH) and os.path.exists(KSL_NORM_STD_PATH):
            ksl_norm_mean = np.load(KSL_NORM_MEAN_PATH)
            ksl_norm_std = np.load(KSL_NORM_STD_PATH)
            print(f"✅ 정적 모델 로드 성공: {len(labels_ksl)}개 라벨 (정규화 적용)")
        else:
            print(f"⚠️ 정규화 파일 없음 - 정적 모델 정확도가 낮을 수 있습니다!")
            print(f"✅ 정적 모델 로드 성공: {len(labels_ksl)}개 라벨 (정규화 없음)")
        
        # 2. 시퀀스 모델 로딩 (쌍자음/복합모음)
        if os.path.exists(KSL_SEQ_MODEL_PATH):
            ksl_seq_model = tf.keras.models.load_model(KSL_SEQ_MODEL_PATH)
            labels_ksl_seq = np.load(KSL_SEQ_LABELS_PATH, allow_pickle=True)
            seq_max_timesteps = int(np.load(KSL_SEQ_CONFIG_PATH))
            
            # 정규화 통계 로드
            if os.path.exists(KSL_SEQ_NORM_MEAN_PATH) and os.path.exists(KSL_SEQ_NORM_STD_PATH):
                seq_norm_mean = np.load(KSL_SEQ_NORM_MEAN_PATH)
                seq_norm_std = np.load(KSL_SEQ_NORM_STD_PATH)
                print(f"✅ 시퀀스 정규화 통계 로드 성공")
            else:
                print("⚠️ 시퀀스 정규화 통계 없음 - 정규화 없이 진행")
            
            print(f"✅ 시퀀스 모델 로드 성공: {len(labels_ksl_seq)}개 라벨 (max_timesteps={seq_max_timesteps})")
        else:
            print("⚠️ 시퀀스 모델 없음 - 쌍자음/복합모음은 규칙 기반으로 처리")
        
        # 3. MediaPipe 초기화 (양손 지원)
        mp_hands = mp.solutions.hands
        hands = mp_hands.Hands(
            static_image_mode=False,  # 시퀀스 지원을 위해 False
            max_num_hands=2,  # 양손 지원
            min_detection_confidence=0.5,
            min_tracking_confidence=0.5
        )
        
        print("✅ 하이브리드 AI 모델 초기화 성공")
        print(f"   - 정적 모델: {KSL_MODEL_PATH}")
        print(f"   - 시퀀스 모델: {KSL_SEQ_MODEL_PATH}")
        return True
        
    except Exception as e:
        print(f"❌ AI 모델 초기화 실패: {e}")
        import traceback
        traceback.print_exc()
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

def analyze_sign_accuracy(image_data, target_sign, language, user_id=None):
    """하이브리드 수어 정확도 분석 (정적 + 시퀀스)"""
    
    # 모델이 초기화되지 않은 경우 폴백
    if not model_initialized or ksl_model is None:
        print("⚠️ AI 모델이 초기화되지 않음. 폴백 모드 사용")
        return fallback_analysis(target_sign, language)
    
    # 시퀀스 모델이 필요한 경우 (쌍자음/복합모음)
    if target_sign in SEQUENCE_SIGNS:
        print(f"🔄 시퀀스 사인 감지: {target_sign}")
        
        # 시퀀스 모델이 없으면 에러 반환
        if ksl_seq_model is None:
            print("❌ 시퀀스 모델 없음 - 학습 필요")
            return {
                'accuracy': 0.0,
                'confidence': 0.0,
                'feedback': {
                    'level': 'error',
                    'message': f'"{target_sign}" 인식을 위한 모델이 준비되지 않았습니다',
                    'suggestions': ['시퀀스 모델 학습이 필요합니다', '관리자에게 문의하세요'],
                    'color': 'red',
                    'score': 'F'
                },
                'hand_detected': False,
                'target_sign': target_sign,
                'predicted_sign': None,
                'is_correct': False,
                'language': language,
                'model_type': 'sequence_not_available',
                'error': 'Sequence model not loaded'
            }
        
        result = analyze_sequence_sign(image_data, target_sign, language, user_id)
        print(f"� 델시퀀스 분석 결과: predicted={result.get('predicted_sign')}, accuracy={result.get('accuracy')}, collecting={result.get('collecting')}")
        return result
    
    # 정적 모델 사용 (기본 자음/모음)
    print(f"📷 정적 모델 사용: {target_sign}")
    return analyze_static_sign(image_data, target_sign, language)

def analyze_sequence_sign(image_data, target_sign, language, user_id):
    """시퀀스 모델을 사용한 수어 분석 (쌍자음/복합모음)"""
    
    print(f"🎬 analyze_sequence_sign 시작: target={target_sign}, user_id={user_id}")
    
    try:
        if user_id is None:
            user_id = "anonymous"
        
        # 사용자별 시퀀스 버퍼 초기화
        if user_id not in sequence_buffers:
            print(f"🆕 새 버퍼 생성: user_id={user_id}")
            sequence_buffers[user_id] = {
                'buffer': deque(maxlen=seq_max_timesteps),
                'prev_xy': {},
                'target': target_sign
            }
        
        user_buffer = sequence_buffers[user_id]
        
        # 목표가 바뀌면 버퍼 초기화 (중요!)
        if user_buffer.get('target') != target_sign:
            print(f"🔄 목표 변경: {user_buffer.get('target')} → {target_sign}, 버퍼 초기화")
            user_buffer['buffer'] = deque(maxlen=seq_max_timesteps)  # 새 deque 생성
            user_buffer['prev_xy'] = {}  # 새 dict 생성
            user_buffer['target'] = target_sign
            print(f"✅ 버퍼 초기화 완료: 크기={len(user_buffer['buffer'])}")
        # 1. 이미지 디코딩
        print(f"📸 Step 1: 이미지 디코딩 시작")
        if not image_data:
            print("⚠️ image_data 없음")
            return {
                'accuracy': 0.0,
                'confidence': 0.0,
                'feedback': {
                    'level': 'error',
                    'message': '이미지 데이터가 없습니다',
                    'suggestions': ['카메라를 확인하세요'],
                    'color': 'red',
                    'score': 'F'
                },
                'hand_detected': False,
                'target_sign': target_sign,
                'predicted_sign': None,
                'is_correct': False,
                'language': language,
                'model_type': 'sequence_no_image',
                'error': 'No image data'
            }
        
        image = decode_base64_image(image_data)
        if image is None:
            print("⚠️ 이미지 디코딩 실패")
            return fallback_analysis(target_sign, language)
        
        print(f"✅ 이미지 디코딩 성공: {image.shape}")
        
        # 2. 이미지 전처리
        print(f"🎨 Step 2: 이미지 전처리")
        image_rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
        
        # 3. MediaPipe로 손 인식
        print(f"👋 Step 3: MediaPipe 손 인식")
        results = hands.process(image_rgb)
        print(f"✅ MediaPipe 처리 완료: 손 감지={results.multi_hand_landmarks is not None}")
        
        if not results.multi_hand_landmarks:
            # 손이 없으면 버퍼 초기화
            if len(user_buffer['buffer']) > 0:
                print(f"👋 손 감지 안됨 - 버퍼 초기화 (이전 크기: {len(user_buffer['buffer'])})")
                user_buffer['buffer'].clear()
                user_buffer['prev_xy'].clear()
            return {
                'accuracy': 0.0,
                'confidence': 0.0,
                'feedback': generate_detailed_feedback(0.0, target_sign, language),
                'hand_detected': False,
                'target_sign': target_sign,
                'language': language,
                'model_type': 'sequence',
                'buffer_size': 0,
                'error': '손이 감지되지 않았습니다'
            }
        
        # 4. 손 랜드마크 추출 (wrist, index_tip만 사용)
        hand_landmarks = results.multi_hand_landmarks[0]
        lms = hand_landmarks.landmark
        
        # 사용할 랜드마크 (capture_sequence.py와 동일)
        USE_LANDMARKS = {0: "wrist", 8: "index_tip"}
        
        frame_features = []
        spd_sum_total = 0.0
        
        # 속도 계산
        for lm_id in USE_LANDMARKS.keys():
            lm = lms[lm_id]
            x, y = float(lm.x), float(lm.y)
            
            dx = dy = 0.0
            if lm_id in user_buffer['prev_xy']:
                dx = x - user_buffer['prev_xy'][lm_id][0]
                dy = y - user_buffer['prev_xy'][lm_id][1]
            
            spd = abs(dx) + abs(dy)
            spd_sum_total += spd
            user_buffer['prev_xy'][lm_id] = (x, y)
        
        # 특징 벡터 생성
        for lm_id in USE_LANDMARKS.keys():
            lm = lms[lm_id]
            x, y = float(lm.x), float(lm.y)
            
            dx = dy = 0.0
            if lm_id in user_buffer['prev_xy']:
                prev_x, prev_y = user_buffer['prev_xy'][lm_id]
                dx = x - prev_x
                dy = y - prev_y
            
            frame_features.extend([x, y, dx, dy, spd_sum_total])
        
        # 버퍼에 추가
        user_buffer['buffer'].append(frame_features)
        
        # 충분한 프레임이 모이면 예측
        buffer_size = len(user_buffer['buffer'])
        min_frames = 5  # 최소 5프레임 (더 안정적인 인식)
        
        print(f"🔢 버퍼 상태: {buffer_size}/{seq_max_timesteps} 프레임 (최소: {min_frames}, 목표: {target_sign})")
        
        if buffer_size < min_frames:
            # 프레임 수집 중
            progress_ratio = buffer_size / min_frames
            collecting_accuracy = 50 + (progress_ratio * 30)  # 50~80%
            
            return {
                'accuracy': collecting_accuracy,
                'confidence': 0.5,
                'feedback': {
                    'level': 'collecting',
                    'message': f'"{target_sign}" 동작을 수집 중입니다... ({buffer_size}/{min_frames})',
                    'suggestions': [
                        '천천히 동작을 계속하세요',
                        '손을 카메라에 잘 보이게 유지하세요'
                    ],
                    'color': 'blue',
                    'score': '-'
                },
                'hand_detected': True,
                'target_sign': target_sign,
                'predicted_sign': None,
                'is_correct': False,
                'language': language,
                'model_type': 'sequence',
                'buffer_size': buffer_size,
                'collecting': True
            }
        
        # 5. 시퀀스 패딩 및 정규화
        feature_dim = len(frame_features)
        seq_array = np.zeros((1, seq_max_timesteps, feature_dim), dtype=np.float32)
        seq_len = len(user_buffer['buffer'])
        seq_array[0, :seq_len, :] = list(user_buffer['buffer'])
        
        # 정규화 적용
        if seq_norm_mean is not None and seq_norm_std is not None:
            seq_array = (seq_array - seq_norm_mean) / seq_norm_std
            print(f"✅ 정규화 적용 완료")
        else:
            print("⚠️ 정규화 통계 없음 - 정규화 없이 예측")
        
        # 6. AI 모델 예측
        prediction = ksl_seq_model.predict(seq_array, verbose=0)
        
        # 7. 결과 분석
        predicted_idx = np.argmax(prediction)
        confidence_score = float(np.max(prediction))
        
        if 0 <= predicted_idx < len(labels_ksl_seq):
            predicted_sign = labels_ksl_seq[predicted_idx]
        else:
            predicted_sign = "UNKNOWN"
        
        # 8. 정확도 계산
        is_correct = predicted_sign == target_sign
        
        # 정확도 계산 (엄격하게)
        if is_correct:
            accuracy = confidence_score * 100
        else:
            # 틀렸으면 낮은 점수
            accuracy = confidence_score * 50
        
        # 9. 피드백 생성
        feedback = generate_detailed_feedback(accuracy, target_sign, language)
        
        # 틀렸을 때 메시지
        if not is_correct:
            feedback['message'] = f'"{predicted_sign}"이(가) 인식되었습니다. "{target_sign}"을(를) 다시 시도하세요'
            feedback['suggestions'] = [
                f'예측: {predicted_sign} ≠ 목표: {target_sign}',
                '동작을 천천히 정확하게 수행하세요',
                '참고 영상을 다시 확인하세요'
            ]
        
        return {
            'accuracy': round(accuracy, 1),
            'confidence': round(confidence_score, 2),
            'feedback': feedback,
            'hand_detected': True,
            'target_sign': target_sign,
            'predicted_sign': predicted_sign,
            'is_correct': is_correct,
            'language': language,
            'model_type': 'sequence',
            'buffer_size': buffer_size
        }
        
    except Exception as e:
        print(f"❌ 시퀀스 분석 중 오류: {e}")
        import traceback
        traceback.print_exc()
        
        # 에러 정보를 포함한 fallback
        fallback_result = fallback_analysis(target_sign, language)
        fallback_result['error'] = str(e)
        fallback_result['error_type'] = 'sequence_analysis_error'
        return fallback_result

def analyze_static_sign(image_data, target_sign, language):
    """정적 모델을 사용한 수어 분석 (기본 자음/모음)"""
    
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
        
        # 5. 정규화 적용 (학습 시와 동일하게)
        input_data = np.array(coords, dtype=np.float32).reshape(1, -1)
        if ksl_norm_mean is not None and ksl_norm_std is not None:
            input_data = (input_data - ksl_norm_mean) / ksl_norm_std
        
        # 6. AI 모델 예측 (H5 모델)
        prediction = ksl_model.predict(input_data, verbose=0)
        
        # 7. 결과 분석
        predicted_idx = np.argmax(prediction)
        confidence_score = float(np.max(prediction))
        
        if 0 <= predicted_idx < len(labels_ksl):
            predicted_sign = labels_ksl[predicted_idx]
        else:
            predicted_sign = "UNKNOWN"
        
        # 8. 쌍자음 처리 로직
        # 목표가 쌍자음이고, 예측이 기본 자음인 경우 처리
        is_double_consonant_target = target_sign in DOUBLE_CONSONANT_MAP.values()
        base_consonant = None
        
        if is_double_consonant_target:
            # 쌍자음의 기본 자음 찾기 (예: ㄸ → ㄷ)
            for base, double in DOUBLE_CONSONANT_MAP.items():
                if double == target_sign:
                    base_consonant = base
                    break
            
            # 기본 자음을 인식한 경우도 부분 점수 부여
            if predicted_sign == base_consonant:
                print(f"🎯 쌍자음 학습: {target_sign} 목표, {predicted_sign} 인식 → 부분 점수")
                # 기본 자음 인식 시 70% 정확도 부여
                accuracy = confidence_score * 70
                is_correct = False  # 완전히 맞지는 않음
                feedback = generate_detailed_feedback(accuracy, target_sign, language)
                feedback['message'] = f'"{predicted_sign}" 모양이 맞아요! 조금 더 강하게 해서 "{target_sign}"을 만들어보세요 💪'
                feedback['suggestions'] = [
                    f'{predicted_sign} 모양에서 손에 더 힘을 주세요',
                    f'손가락을 더 굽혀서 {target_sign}을 표현하세요',
                    '쌍자음은 기본 자음보다 강한 느낌입니다'
                ]
                
                return {
                    'accuracy': round(accuracy, 1),
                    'confidence': round(confidence_score, 2),
                    'feedback': feedback,
                    'hand_detected': True,
                    'target_sign': target_sign,
                    'predicted_sign': predicted_sign,
                    'is_correct': is_correct,
                    'is_partial_match': True,
                    'base_consonant': base_consonant,
                    'language': language
                }
        
        # 9. 정확도 계산 (일반 케이스)
        is_correct = predicted_sign == target_sign
        accuracy = confidence_score * 100 if is_correct else max(0, confidence_score * 50)
        
        # 10. 피드백 생성
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
        'ㄲ': 0.6, 'ㄸ': 0.6, 'ㅃ': 0.6, 'ㅆ': 0.7, 'ㅉ': 0.6,  # 쌍자음은 더 어려움
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
        
        # 5. 정규화 적용 (학습 시와 동일하게)
        input_data = np.array(coords, dtype=np.float32).reshape(1, -1)
        if ksl_norm_mean is not None and ksl_norm_std is not None:
            input_data = (input_data - ksl_norm_mean) / ksl_norm_std
        
        # 6. AI 모델 예측 (H5 모델)
        prediction = ksl_model.predict(input_data, verbose=0)
        
        # 7. 결과 분석
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
    """손모양 분석 및 정확도 측정 (하이브리드)"""
    try:
        user_id = get_jwt_identity()
        data = request.get_json()
        
        # 필수 데이터 확인
        required_fields = ['target_sign', 'language']
        for field in required_fields:
            if not data.get(field):
                return jsonify({'error': f'{field}는 필수입니다.'}), 400
        
        target_sign = data['target_sign']
        language = data['language']
        
        # 이미지 데이터 가져오기 (프론트엔드에서 보내거나, 캐시에서 가져오기)
        image_data = data.get('image_data', '')
        
        # 이미지 데이터가 없으면 파일에서 프레임 로드
        if not image_data:
            import tempfile
            import base64
            
            frame_path = os.path.join(tempfile.gettempdir(), f'ksl_frame_{language}.jpg')
            
            if os.path.exists(frame_path):
                # 파일에서 이미지 읽기
                frame = cv2.imread(frame_path)
                if frame is not None:
                    # Base64로 인코딩
                    _, buffer = cv2.imencode('.jpg', frame)
                    image_data = 'data:image/jpeg;base64,' + base64.b64encode(buffer).decode('utf-8')
                    print(f"📸 파일에서 프레임 로드: {frame.shape}")
                else:
                    print(f"⚠️ 프레임 파일 읽기 실패: {frame_path}")
            else:
                print(f"⚠️ 프레임 파일 없음: {frame_path}")
        
        # 손모양 분석 수행 (하이브리드)
        analysis_result = analyze_sign_accuracy(
            image_data,
            target_sign,
            language,
            user_id=user_id
        )
        
        # 모델 타입 결정
        model_type = 'sequence' if target_sign in SEQUENCE_SIGNS else 'static'
        
        return jsonify({
            'analysis': analysis_result,
            'message': '손모양 분석이 완료되었습니다.',
            'model_type': model_type,
            'is_sequence_sign': target_sign in SEQUENCE_SIGNS
        }), 200
        
    except Exception as e:
        import traceback
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500

# ===== 모델 상태 확인 API =====

@recognition_bp.route('/api/recognition/model-status', methods=['GET'])
def get_model_status():
    """AI 모델 상태 확인 (하이브리드)"""
    try:
        # 파일 존재 여부 확인
        files_exist = {
            'ksl_model.h5': os.path.exists(KSL_MODEL_PATH),
            'ksl_labels.npy': os.path.exists(KSL_LABELS_PATH),
            'ksl_model_sequence.h5': os.path.exists(KSL_SEQ_MODEL_PATH),
            'ksl_labels_sequence.npy': os.path.exists(KSL_SEQ_LABELS_PATH),
            'ksl_sequence_config.npy': os.path.exists(KSL_SEQ_CONFIG_PATH)
        }
        
        status = {
            'model_initialized': model_initialized,
            'hybrid_mode': True,
            'mediapipe_available': hands is not None,
            'files_exist': files_exist,
            
            # 정적 모델
            'static_model': {
                'available': ksl_model is not None,
                'path': KSL_MODEL_PATH,
                'labels_count': len(labels_ksl) if labels_ksl is not None else 0,
                'labels': labels_ksl.tolist() if labels_ksl is not None else []
            },
            
            # 시퀀스 모델
            'sequence_model': {
                'available': ksl_seq_model is not None,
                'path': KSL_SEQ_MODEL_PATH,
                'labels_count': len(labels_ksl_seq) if labels_ksl_seq is not None else 0,
                'labels': labels_ksl_seq.tolist() if labels_ksl_seq is not None else [],
                'max_timesteps': seq_max_timesteps
            },
            
            'sequence_signs': SEQUENCE_SIGNS,
            
            # 디버깅 정보
            'debug': {
                'base_dir': BASE_DIR,
                'model_dir': MODEL_DIR,
                'seq_model_loaded': ksl_seq_model is not None,
                'seq_labels_loaded': labels_ksl_seq is not None,
                'seq_config_loaded': seq_max_timesteps is not None
            }
        }
        
        return jsonify(status), 200
        
    except Exception as e:
        import traceback
        return jsonify({
            'error': str(e),
            'traceback': traceback.format_exc()
        }), 500

@recognition_bp.route('/api/recognition/clear-buffer', methods=['POST'])
@jwt_required()
def clear_sequence_buffer():
    """시퀀스 버퍼 초기화"""
    try:
        user_id = get_jwt_identity()
        
        if user_id in sequence_buffers:
            sequence_buffers[user_id]['buffer'].clear()
            sequence_buffers[user_id]['prev_xy'].clear()
            return jsonify({
                'message': '시퀀스 버퍼가 초기화되었습니다.',
                'user_id': user_id
            }), 200
        else:
            return jsonify({
                'message': '초기화할 버퍼가 없습니다.',
                'user_id': user_id
            }), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500