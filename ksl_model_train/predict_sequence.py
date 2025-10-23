import cv2
import numpy as np
import mediapipe as mp
from tensorflow.keras.models import load_model
from collections import deque
import os

# 경로 설정
BASE_DIR = os.path.dirname(__file__)
MODEL_DIR = os.path.join(BASE_DIR, "model")

# 모델 및 설정 로드
print("Loading sequence model...")
model = load_model(os.path.join(MODEL_DIR, "ksl_sequence_model.h5"))
labels = np.load(os.path.join(MODEL_DIR, "ksl_seq_labels.npy"), allow_pickle=True)
max_timesteps = int(np.load(os.path.join(MODEL_DIR, "ksl_seq_max_timesteps.npy")))
norm_mean = np.load(os.path.join(MODEL_DIR, "ksl_seq_norm_mean.npy"))
norm_std = np.load(os.path.join(MODEL_DIR, "ksl_seq_norm_std.npy"))

print(f"Model loaded successfully!")
print(f"Labels: {labels}")
print(f"Max timesteps: {max_timesteps}")

# MediaPipe Hands 설정
mp_hands = mp.solutions.hands
mp_drawing = mp.solutions.drawing_utils
hands = mp_hands.Hands(
    static_image_mode=False,
    max_num_hands=1,
    min_detection_confidence=0.5,
    min_tracking_confidence=0.5
)

# 사용할 랜드마크 (capture_sequence.py와 동일)
USE_LANDMARKS = {
    0: "wrist",
    8: "index_tip",
}

# 시퀀스 버퍼
sequence_buffer = deque(maxlen=max_timesteps)
prev_xy = {}

# 웹캠 시작
cap = cv2.VideoCapture(0)
if not cap.isOpened():
    print("Error: Could not open webcam.")
    exit()

print("\n=== 실시간 시퀀스 인식 시작 ===")
print("ESC: 종료 | SPACE: 시퀀스 버퍼 초기화")
print("쌍자음/복합모음 수어를 하세요!")

prediction_text = "대기 중..."
confidence = 0.0

while True:
    ret, frame = cap.read()
    if not ret:
        print("Error: Failed to capture frame.")
        break
    
    image = cv2.flip(frame, 1)
    rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
    result = hands.process(rgb)
    
    # 손 랜드마크 그리기
    if result.multi_hand_landmarks:
        for hand_landmarks in result.multi_hand_landmarks:
            mp_drawing.draw_landmarks(
                image, hand_landmarks, mp_hands.HAND_CONNECTIONS
            )
            
            # 특징 추출
            lms = hand_landmarks.landmark
            frame_features = []
            spd_sum_total = 0.0
            
            for lm_id in USE_LANDMARKS.keys():
                lm = lms[lm_id]
                x, y = float(lm.x), float(lm.y)
                vis = float(getattr(lm, "visibility", 1.0))
                
                dx = dy = 0.0
                if lm_id in prev_xy:
                    dx = x - prev_xy[lm_id][0]
                    dy = y - prev_xy[lm_id][1]
                
                spd = abs(dx) + abs(dy)
                spd_sum_total += spd
                prev_xy[lm_id] = (x, y)
            
            # 모든 랜드마크의 특징을 하나의 벡터로
            for lm_id in USE_LANDMARKS.keys():
                lm = lms[lm_id]
                x, y = float(lm.x), float(lm.y)
                
                dx = dy = 0.0
                if lm_id in prev_xy:
                    dx = x - prev_xy[lm_id][0]
                    dy = y - prev_xy[lm_id][1]
                
                frame_features.extend([x, y, dx, dy, spd_sum_total])
            
            # 버퍼에 추가
            sequence_buffer.append(frame_features)
            
            # 충분한 프레임이 모이면 예측
            if len(sequence_buffer) >= max_timesteps // 2:  # 최소 절반 이상
                # 패딩 적용
                seq_array = np.zeros((1, max_timesteps, len(frame_features)), dtype=np.float32)
                seq_len = len(sequence_buffer)
                seq_array[0, :seq_len, :] = list(sequence_buffer)
                
                # 정규화
                seq_array = (seq_array - norm_mean) / norm_std
                
                # 예측
                pred = model.predict(seq_array, verbose=0)[0]
                pred_idx = np.argmax(pred)
                confidence = pred[pred_idx]
                
                if confidence > 0.5:  # 신뢰도 임계값
                    prediction_text = f"{labels[pred_idx]}"
                else:
                    prediction_text = "불확실"
    else:
        # 손이 감지되지 않으면 버퍼 초기화
        if len(sequence_buffer) > 0:
            sequence_buffer.clear()
            prev_xy.clear()
        prediction_text = "손 감지 안됨"
        confidence = 0.0
    
    # UI 표시
    cv2.putText(
        image,
        f"예측: {prediction_text}",
        (10, 40),
        cv2.FONT_HERSHEY_SIMPLEX,
        1.2,
        (0, 255, 0) if confidence > 0.5 else (0, 165, 255),
        3
    )
    
    cv2.putText(
        image,
        f"신뢰도: {confidence*100:.1f}%",
        (10, 80),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.7,
        (255, 255, 255),
        2
    )
    
    cv2.putText(
        image,
        f"버퍼: {len(sequence_buffer)}/{max_timesteps}",
        (10, 110),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.6,
        (200, 200, 200),
        2
    )
    
    cv2.imshow("KSL Sequence Recognition (쌍자음/복합모음)", image)
    
    key = cv2.waitKey(1) & 0xFF
    if key == 27:  # ESC
        break
    elif key == 32:  # SPACE
        sequence_buffer.clear()
        prev_xy.clear()
        print("버퍼 초기화")

cap.release()
cv2.destroyAllWindows()
hands.close()
print("종료")
