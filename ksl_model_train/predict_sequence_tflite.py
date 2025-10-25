"""
시퀀스 모델 (Bidirectional LSTM) TFLite 추론 스크립트
라즈베리파이 3 및 임베디드 환경용
"""
import os
import sys
import numpy as np
import cv2
import mediapipe as mp
import time
from collections import deque

# TFLite 인터프리터 import
try:
    from tflite_runtime.interpreter import Interpreter
    print("✅ tflite_runtime 사용")
except Exception:
    try:
        from tensorflow.lite.python.interpreter import Interpreter
        print("✅ tensorflow.lite 사용")
    except Exception as e:
        print("❌ TFLite Interpreter를 찾을 수 없습니다:", e)
        sys.exit(1)

# 경로 설정
BASE_DIR = os.path.dirname(__file__)
MODEL_DIR = os.path.join(BASE_DIR, "model")

# 모델 파일 선택 (우선순위: FP16 > FP32 > INT8)
TFLITE_FP16 = os.path.join(MODEL_DIR, "ksl_sequence_fp16.tflite")
TFLITE_FP32 = os.path.join(MODEL_DIR, "ksl_sequence_fp32.tflite")
TFLITE_INT8 = os.path.join(MODEL_DIR, "ksl_sequence_int8.tflite")

LABELS_PATH = os.path.join(MODEL_DIR, "ksl_seq_labels.npy")
MAX_TIMESTEPS_PATH = os.path.join(MODEL_DIR, "ksl_seq_max_timesteps.npy")
NORM_MEAN_PATH = os.path.join(MODEL_DIR, "ksl_seq_norm_mean.npy")
NORM_STD_PATH = os.path.join(MODEL_DIR, "ksl_seq_norm_std.npy")

# 라벨 및 정규화 통계 로드
if not os.path.exists(LABELS_PATH):
    print(f"❌ 라벨 파일을 찾을 수 없습니다: {LABELS_PATH}")
    sys.exit(1)

labels = np.load(LABELS_PATH, allow_pickle=True)
max_timesteps = int(np.load(MAX_TIMESTEPS_PATH))
norm_mean = np.load(NORM_MEAN_PATH)
norm_std = np.load(NORM_STD_PATH)

print(f"✅ 라벨 로드: {labels}")
print(f"✅ Max timesteps: {max_timesteps}")

# 모델 선택
if os.path.exists(TFLITE_FP16):
    model_path = TFLITE_FP16
    print(f"✅ FP16 모델 사용 (권장)")
elif os.path.exists(TFLITE_FP32):
    model_path = TFLITE_FP32
    print(f"✅ FP32 모델 사용")
elif os.path.exists(TFLITE_INT8):
    model_path = TFLITE_INT8
    print(f"✅ INT8 모델 사용")
else:
    print("❌ TFLite 모델을 찾을 수 없습니다.")
    print("   export_sequence_tflite.py를 먼저 실행하세요.")
    sys.exit(1)

print(f"📂 모델 경로: {model_path}")
print(f"📦 모델 크기: {os.path.getsize(model_path) / 1024 / 1024:.2f} MB")

# 인터프리터 설정
print("\n🔧 TFLite 인터프리터 초기화 중...")
interpreter = Interpreter(model_path=model_path, num_threads=2)
interpreter.allocate_tensors()

input_details = interpreter.get_input_details()
output_details = interpreter.get_output_details()

print(f"   입력 shape: {input_details[0]['shape']}")
print(f"   입력 dtype: {input_details[0]['dtype']}")
print(f"   출력 shape: {output_details[0]['shape']}")
print(f"   출력 dtype: {output_details[0]['dtype']}")

# MediaPipe 설정
mp_hands = mp.solutions.hands
hands = mp_hands.Hands(
    static_image_mode=False,
    max_num_hands=1,
    min_detection_confidence=0.5,
    min_tracking_confidence=0.5,
)
mp_draw = mp.solutions.drawing_utils

# 카메라 열기
cap = cv2.VideoCapture(0)
if not cap.isOpened():
    print("❌ 카메라를 열 수 없습니다.")
    sys.exit(1)

print("✅ 카메라 열기 성공")

# 시퀀스 버퍼 (0.5~0.8초 분량)
sequence_buffer = deque(maxlen=max_timesteps)
feature_dim = norm_mean.shape[0]

print("\n" + "="*60)
print("🎯 시퀀스 인식 시작")
print("="*60)
print("조작법:")
print("  - 손을 움직여 쌍자음/복합모음 표현")
print("  - 자동으로 시퀀스 인식 (0.5초 이상 손 감지 시)")
print("  - SPACE: 버퍼 초기화")
print("  - ESC: 종료")
print("="*60)

latest_char = ""
last_prediction_time = 0
prediction_interval = 0.5  # 0.5초마다 예측
confidence_threshold = 0.6

# 성능 측정
frame_count = 0
start_time = time.time()

try:
    while cap.isOpened():
        ret, frame = cap.read()
        if not ret:
            print("❌ 프레임 읽기 실패")
            break

        frame_count += 1
        image = cv2.flip(frame, 1)
        rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
        result = hands.process(rgb)

        current_time = time.time()

        # 손 랜드마크 그리기
        if result.multi_hand_landmarks:
            for hand_landmarks in result.multi_hand_landmarks:
                mp_draw.draw_landmarks(image, hand_landmarks, mp_hands.HAND_CONNECTIONS)

                # 특징 추출
                features = []
                lm_list = list(hand_landmarks.landmark)
                
                for i, lm in enumerate(lm_list):
                    features.extend([lm.x, lm.y])
                    
                    # dx, dy, spd_sum 계산 (간단한 근사)
                    if i > 0:
                        prev_lm = lm_list[i-1]
                        dx = lm.x - prev_lm.x
                        dy = lm.y - prev_lm.y
                        spd = np.sqrt(dx**2 + dy**2)
                    else:
                        dx, dy, spd = 0, 0, 0
                    
                    features.extend([dx, dy, spd])
                
                # 버퍼에 추가
                sequence_buffer.append(features[:feature_dim])

                # 예측 (충분한 프레임이 쌓이면)
                if (len(sequence_buffer) >= max_timesteps // 2 and 
                    current_time - last_prediction_time >= prediction_interval):
                    
                    # 시퀀스 패딩
                    padded_seq = np.zeros((1, max_timesteps, feature_dim), dtype=np.float32)
                    seq_len = min(len(sequence_buffer), max_timesteps)
                    
                    for i, frame_features in enumerate(list(sequence_buffer)[-seq_len:]):
                        padded_seq[0, i, :] = frame_features
                    
                    # 정규화
                    padded_seq = (padded_seq - norm_mean) / norm_std
                    
                    # 추론
                    interpreter.set_tensor(input_details[0]['index'], padded_seq)
                    interpreter.invoke()
                    output_data = interpreter.get_tensor(output_details[0]['index'])
                    
                    probs = output_data.reshape(-1)
                    idx = int(np.argmax(probs))
                    confidence = float(np.max(probs))
                    
                    if 0 <= idx < len(labels) and confidence > confidence_threshold:
                        latest_char = labels[idx]
                        print(f"🎯 인식: {latest_char} (신뢰도: {confidence:.3f}, 버퍼: {len(sequence_buffer)}프레임)")
                    
                    last_prediction_time = current_time
        else:
            # 손이 없으면 버퍼 유지 (일시적 가림 대응)
            pass

        # 화면 표시
        cv2.putText(image, f"Char: {latest_char}", (10, 30),
                    cv2.FONT_HERSHEY_SIMPLEX, 1.0, (0, 255, 0), 2)
        cv2.putText(image, f"Buffer: {len(sequence_buffer)}/{max_timesteps}", (10, 60),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 0, 0), 2)
        
        # FPS 표시
        if frame_count % 30 == 0:
            elapsed = time.time() - start_time
            fps = frame_count / elapsed
            cv2.putText(image, f"FPS: {fps:.1f}", (10, 90),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 0, 255), 2)

        cv2.imshow("KSL Sequence TFLite (쌍자음/복합모음)", image)
        
        key = cv2.waitKey(10) & 0xFF
        if key == 27:  # ESC
            break
        elif key == 32:  # SPACE
            sequence_buffer.clear()
            latest_char = ""
            print("🔄 버퍼 초기화")

except KeyboardInterrupt:
    print("\n⚠️  사용자 중단")

finally:
    # 최종 성능 통계
    elapsed = time.time() - start_time
    fps = frame_count / elapsed
    
    print("\n" + "="*60)
    print("📊 성능 통계")
    print("="*60)
    print(f"총 프레임: {frame_count}")
    print(f"실행 시간: {elapsed:.2f}초")
    print(f"평균 FPS: {fps:.2f}")
    print(f"모델: {os.path.basename(model_path)}")
    print("="*60)
    
    cap.release()
    cv2.destroyAllWindows()
    hands.close()
    print("✅ 종료 완료")
