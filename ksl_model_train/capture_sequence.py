import os
import csv
import time
import cv2
import mediapipe as mp
from collections import deque
from datetime import datetime

# Paths
BASE_DIR = os.path.dirname(__file__)
OUT_ROOT = os.path.join(BASE_DIR, "data_seq")
os.makedirs(OUT_ROOT, exist_ok=True)

# Capture params
FPS_TARGET = 20
WINDOW_FRAMES = 16  # ~0.8s at 20fps; adjust to 12 for ~0.6s
USE_LANDMARKS = {
    0: "wrist",
    8: "index_tip",
}

# Target count
TARGET_COUNT = 50  # 목표 수집 개수

# Ask label
label = ""
while not label.strip():
    label = input("라벨 입력 (예: ㄱ, ㄲ, ㅘ): ").strip()

label_dir = os.path.join(OUT_ROOT, label)
os.makedirs(label_dir, exist_ok=True)

# 기존 파일 개수 확인
existing_count = len([f for f in os.listdir(label_dir) if f.endswith('.csv')])
print(f"\n📊 현재 '{label}' 데이터: {existing_count}개")
print(f"🎯 목표: {TARGET_COUNT}개 (남은 개수: {max(0, TARGET_COUNT - existing_count)}개)")
print(f"{'='*60}\n")

# MediaPipe Hands
mp_hands = mp.solutions.hands
hands = mp_hands.Hands(
    static_image_mode=False,
    max_num_hands=1,
    min_detection_confidence=0.5,
    min_tracking_confidence=0.5,
)

cap = cv2.VideoCapture(0)
if not cap.isOpened():
    print("Error: Could not open webcam.")
    raise SystemExit(1)

print("SPACE: 0.5~0.8초 클립 캡처 | ESC: 종료")

# Helper to write one sequence CSV

def write_sequence_csv(seq_rows, out_dir, label):
    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    fname = f"{label}_{ts}.csv"
    fpath = os.path.join(out_dir, fname)
    fieldnames = [
        "frame",
        "landmark_id",
        "name",
        "x",
        "y",
        "visibility",
        "dx",
        "dy",
        "spd_sum",
    ]
    with open(fpath, "w", newline="", encoding="utf-8") as wf:
        writer = csv.DictWriter(wf, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(seq_rows)
    return fpath

# Ring buffer for last frame to compute deltas
prev_xy = {}

while True:
    ret, frame = cap.read()
    if not ret:
        print("Error: Failed to capture frame.")
        break

    image = cv2.flip(frame, 1)
    rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
    result = hands.process(rgb)

    if result.multi_hand_landmarks:
        for hand_landmarks in result.multi_hand_landmarks:
            mp.solutions.drawing_utils.draw_landmarks(
                image, hand_landmarks, mp_hands.HAND_CONNECTIONS
            )

    cv2.putText(
        image,
        f"Label: {label} | WINDOW_FRAMES: {WINDOW_FRAMES}",
        (10, 30),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.7,
        (0, 255, 0),
        2,
    )
    cv2.imshow("Sequence Capture (KSL)", image)

    key = cv2.waitKey(int(1000 / FPS_TARGET)) & 0xFF
    if key == 27:  # ESC
        break
    if key != 32:  # not SPACE
        continue

    # On SPACE: capture a short sequence
    print("⏱️  3초 후 녹화 시작! 준비하세요...")
    
    # 3초 카운트다운
    for countdown in range(3, 0, -1):
        ret_cd, frame_cd = cap.read()
        if ret_cd:
            img_cd = cv2.flip(frame_cd, 1)
            cv2.putText(
                img_cd,
                f"Recording in {countdown}...",
                (50, 100),
                cv2.FONT_HERSHEY_SIMPLEX,
                2,
                (0, 0, 255),
                3,
            )
            cv2.imshow("Sequence Capture (KSL)", img_cd)
            cv2.waitKey(1000)
    
    print("🎬 녹화 시작! 지금 움직이세요!")
    
    seq_rows = []
    prev_xy = {}
    frames_to_capture = WINDOW_FRAMES

    for fi in range(frames_to_capture):
        ret2, frame2 = cap.read()
        if not ret2:
            break
        img2 = cv2.flip(frame2, 1)
        rgb2 = cv2.cvtColor(img2, cv2.COLOR_BGR2RGB)
        res2 = hands.process(rgb2)
        
        # 손 랜드마크 그리기
        if res2.multi_hand_landmarks:
            for hand_landmarks in res2.multi_hand_landmarks:
                mp.solutions.drawing_utils.draw_landmarks(
                    img2, hand_landmarks, mp_hands.HAND_CONNECTIONS
                )
        
        # 녹화 중 표시
        cv2.circle(img2, (30, 30), 15, (0, 0, 255), -1)  # 빨간 점
        cv2.putText(
            img2,
            f"RECORDING... {fi+1}/{frames_to_capture}",
            (60, 40),
            cv2.FONT_HERSHEY_SIMPLEX,
            1,
            (0, 0, 255),
            2,
        )
        cv2.imshow("Sequence Capture (KSL)", img2)
        cv2.waitKey(1)

        if res2.multi_hand_landmarks:
            lms = res2.multi_hand_landmarks[0].landmark
            # Collect only selected landmarks
            cur_frame_rows = []
            spd_sum_total = 0.0
            for lm_id, lm_name in USE_LANDMARKS.items():
                lm = lms[lm_id]
                x, y, vis = float(lm.x), float(lm.y), float(getattr(lm, "visibility", 1.0))
                dx = dy = 0.0
                if lm_id in prev_xy:
                    dx = x - prev_xy[lm_id][0]
                    dy = y - prev_xy[lm_id][1]
                spd = abs(dx) + abs(dy)
                spd_sum_total += spd
                cur_frame_rows.append({
                    "frame": fi,
                    "landmark_id": lm_id,
                    "name": lm_name,
                    "x": x,
                    "y": y,
                    "visibility": vis,
                    "dx": dx,
                    "dy": dy,
                    "spd_sum": None,  # fill after sum for the frame
                })
                prev_xy[lm_id] = (x, y)

            # Fill spd_sum for each row of this frame (same total)
            for r in cur_frame_rows:
                r["spd_sum"] = spd_sum_total
            seq_rows.extend(cur_frame_rows)
        else:
            # No hand detected: still write placeholders for consistency if desired
            pass

        # pace capture
        time.sleep(max(0, 1.0 / FPS_TARGET - 0.001))

    print(f"🎬 녹화 완료! {len(seq_rows)}개 프레임 수집됨")
    
    if seq_rows:
        out_path = write_sequence_csv(seq_rows, label_dir, label)
        current_count = len([f for f in os.listdir(label_dir) if f.endswith('.csv')])
        remaining = max(0, TARGET_COUNT - current_count)
        
        print(f"✅ 저장 완료: {os.path.basename(out_path)} | 프레임: ~{frames_to_capture}")
        print(f"📊 진행률: {current_count}/{TARGET_COUNT}개 (남은 개수: {remaining}개)")
        
        # 카메라 화면에 저장 완료 메시지 표시 (2초간)
        for _ in range(40):  # 2초 = 40 프레임 (20fps)
            ret_msg, frame_msg = cap.read()
            if ret_msg:
                img_msg = cv2.flip(frame_msg, 1)
                
                # 배경 박스
                cv2.rectangle(img_msg, (50, 80), (590, 200), (0, 255, 0), -1)
                
                # 저장 완료 메시지
                cv2.putText(
                    img_msg,
                    "SAVED!",
                    (200, 130),
                    cv2.FONT_HERSHEY_SIMPLEX,
                    2,
                    (255, 255, 255),
                    4,
                )
                
                # 진행률
                cv2.putText(
                    img_msg,
                    f"{current_count}/{TARGET_COUNT} ({remaining} left)",
                    (150, 180),
                    cv2.FONT_HERSHEY_SIMPLEX,
                    1,
                    (255, 255, 255),
                    2,
                )
                
                cv2.imshow("Sequence Capture (KSL)", img_msg)
                cv2.waitKey(50)
        
        # 목표 달성 시 알림
        if current_count >= TARGET_COUNT:
            print(f"\n{'='*60}")
            print(f"🎉🎉🎉 축하합니다! '{label}' 데이터 수집 완료! 🎉🎉🎉")
            print(f"총 {current_count}개 수집됨 (목표: {TARGET_COUNT}개)")
            print(f"{'='*60}\n")
            print("다른 라벨을 수집하려면 ESC를 누르고 다시 실행하세요.")
            
            # 카메라 화면에도 완료 메시지
            for _ in range(60):  # 3초간 표시
                ret_done, frame_done = cap.read()
                if ret_done:
                    img_done = cv2.flip(frame_done, 1)
                    cv2.rectangle(img_done, (30, 100), (610, 300), (0, 255, 0), -1)
                    cv2.putText(
                        img_done,
                        "COMPLETE!",
                        (120, 180),
                        cv2.FONT_HERSHEY_SIMPLEX,
                        2.5,
                        (255, 255, 255),
                        5,
                    )
                    cv2.putText(
                        img_done,
                        f"{current_count}/{TARGET_COUNT} collected",
                        (150, 250),
                        cv2.FONT_HERSHEY_SIMPLEX,
                        1.2,
                        (255, 255, 255),
                        3,
                    )
                    cv2.imshow("Sequence Capture (KSL)", img_done)
                    cv2.waitKey(50)
        print()
    else:
        print("❌ 손이 감지되지 않았습니다. 다시 시도하세요.\n")
        
        # 카메라 화면에 에러 메시지
        for _ in range(40):  # 2초간 표시
            ret_err, frame_err = cap.read()
            if ret_err:
                img_err = cv2.flip(frame_err, 1)
                cv2.rectangle(img_err, (50, 100), (590, 200), (0, 0, 255), -1)
                cv2.putText(
                    img_err,
                    "NO HAND DETECTED!",
                    (80, 160),
                    cv2.FONT_HERSHEY_SIMPLEX,
                    1.5,
                    (255, 255, 255),
                    3,
                )
                cv2.imshow("Sequence Capture (KSL)", img_err)
                cv2.waitKey(50)

cap.release()
cv2.destroyAllWindows()
hands.close()
