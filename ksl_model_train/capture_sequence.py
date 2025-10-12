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

# Ask label
label = ""
while not label.strip():
    label = input("라벨 입력 (예: ㄱ, ㄲ, ㅘ): ").strip()

label_dir = os.path.join(OUT_ROOT, label)
os.makedirs(label_dir, exist_ok=True)

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

    if seq_rows:
        out_path = write_sequence_csv(seq_rows, label_dir, label)
        print(f"Saved sequence: {out_path} | frames: ~{frames_to_capture}")
    else:
        print("No sequence captured (hand not detected). Try again.")

cap.release()
cv2.destroyAllWindows()
hands.close()
