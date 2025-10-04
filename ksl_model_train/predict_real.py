import cv2
import mediapipe as mp
import numpy as np
from tensorflow.keras.models import load_model
from PIL import ImageFont, ImageDraw, Image
import os
from collections import deque

"""All file paths are resolved relative to this script directory."""
BASE_DIR = os.path.dirname(__file__)

# 기본 설정
MODEL_PATH = os.path.join(BASE_DIR, "model", "ksl_model.h5")
LABELS_PATH = os.path.join(BASE_DIR, "model", "ksl_labels.npy")
NORM_MEAN_PATH = os.path.join(BASE_DIR, "model", "ksl_norm_mean.npy")
NORM_STD_PATH = os.path.join(BASE_DIR, "model", "ksl_norm_std.npy")
FONT_FILENAME = "NanumGothic.ttf"
DEFAULT_FONT_PATH = os.path.join(BASE_DIR, FONT_FILENAME)
FONT_SIZE = 60
TEXT_POSITION = (50, 30)
TEXT_COLOR_RGB = (0, 0, 255)
BOX_COLOR_BGR = (255, 0, 0)

# Ring buffer and motion heuristic params
WINDOW_FRAMES = 14  # slightly shorter window for responsiveness
THRESH_STD = 1.0    # peak threshold: mean + THRESH_STD * std (balanced)
MIN_PEAKS = 2
MIN_GAP = 3         # frames between peaks
MAX_GAP = 8

# Landmarks to compute motion energy
MOTION_LANDMARK_IDS = (0, 8)  # wrist, index_tip
MOTION_WEIGHTS = {0: 0.3, 8: 0.7}  # balanced weighting

# Display behavior: hold final decision on-screen for N frames
DISPLAY_HOLD_FRAMES = 20

# 모델, 라벨, 정규화 통계 로딩
try:
    model = load_model(MODEL_PATH)
    labels = np.load(LABELS_PATH, allow_pickle=True)
    norm_mean = np.load(NORM_MEAN_PATH)
    norm_std = np.load(NORM_STD_PATH)
except Exception as e:
    print(f"Error loading model or labels: {e}")
    exit()

# Mediapipe 세팅
mp_hands = mp.solutions.hands
hands = mp_hands.Hands(
    static_image_mode=False,
    max_num_hands=1,
    min_detection_confidence=0.5,
    min_tracking_confidence=0.5)
mp_draw = mp.solutions.drawing_utils

# 카메라
cap = cv2.VideoCapture(0)
if not cap.isOpened():
    print("Error: Could not open webcam.")
    exit()

# 폰트 설정
font_path_to_use = DEFAULT_FONT_PATH
if not os.path.exists(font_path_to_use):
    font_path_to_use_windows = "C:/Windows/Fonts/malgun.ttf"
    if os.path.exists(font_path_to_use_windows):
        font_path_to_use = font_path_to_use_windows
    else:
        font_path_to_use = None

pil_font = None
if font_path_to_use:
    try:
        pil_font = ImageFont.truetype(font_path_to_use, FONT_SIZE)
    except:
        pil_font = None

print("Press SPACE to recognize the sign, ESC to exit.")

latest_char = ""
base_label_buffer = deque(maxlen=WINDOW_FRAMES)
motion_buffer = deque(maxlen=WINDOW_FRAMES)
prev_xy = {}
hold_counter = 0

# Mapping base consonant -> tense consonant
BASE_TO_TENSE = {
    "ㄱ": "ㄲ",
    "ㄷ": "ㄸ",
    "ㅂ": "ㅃ",
    "ㅅ": "ㅆ",
    "ㅈ": "ㅉ",
}
BASE_MAJORITY_MIN = 0.65  # require >=65% of recent frames to share base label

def majority_label(labels_list):
    if not labels_list:
        return None
    counts = {}
    for l in labels_list:
        counts[l] = counts.get(l, 0) + 1
    label, cnt = max(counts.items(), key=lambda x: x[1])
    frac = cnt / max(1, len(labels_list))
    return label, frac

def count_motion_peaks(values, min_gap=MIN_GAP, max_gap=MAX_GAP, thresh_std=THRESH_STD):
    if not values:
        return 0, []
    arr = np.array(values, dtype=np.float32)
    mean = float(np.mean(arr))
    std = float(np.std(arr))
    thresh = mean + thresh_std * std
    peak_idxs = [i for i, v in enumerate(arr) if v >= thresh]
    # merge consecutive indices into single peaks
    merged = []
    for idx in peak_idxs:
        if not merged or idx - merged[-1] > 1:
            merged.append(idx)
    # enforce gap constraints by selecting peaks with proper spacing
    selected = []
    for idx in merged:
        if not selected:
            selected.append(idx)
        else:
            gap = idx - selected[-1]
            if gap >= min_gap:
                selected.append(idx)
    # filter by max_gap pairwise if needed (keep peaks where any adjacent gap <= max_gap)
    filtered = []
    for i, idx in enumerate(selected):
        if i == 0:
            filtered.append(idx)
        else:
            gap = idx - selected[i-1]
            if gap <= max_gap:
                filtered.append(idx)
            else:
                # if too far, start a new group
                filtered = [idx]
    return len(filtered), filtered

while cap.isOpened():
    ret, frame = cap.read()
    if not ret:
        print("Error: Failed to capture image.")
        break

    image = cv2.flip(frame, 1)
    rgb_image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
    result = hands.process(rgb_image)

    if result.multi_hand_landmarks:
        for hand_landmarks in result.multi_hand_landmarks:
            mp_draw.draw_landmarks(image, hand_landmarks, mp_hands.HAND_CONNECTIONS)

        # Per-frame prediction and motion measurement
        hand_landmarks = result.multi_hand_landmarks[0]
        # Build coords for classifier (x,y for 21 landmarks)
        coords = []
        for lm in hand_landmarks.landmark:
            coords.extend([lm.x, lm.y])

        # Compute motion energy from wrist/index_tip
        spd_sum = 0.0
        for lm_id in MOTION_LANDMARK_IDS:
            lm = hand_landmarks.landmark[lm_id]
            x, y = float(lm.x), float(lm.y)
            if lm_id in prev_xy:
                dx = x - prev_xy[lm_id][0]
                dy = y - prev_xy[lm_id][1]
                w = MOTION_WEIGHTS.get(lm_id, 0.5)
                spd_sum += w * (abs(dx) + abs(dy))
            prev_xy[lm_id] = (x, y)
        motion_buffer.append(spd_sum)

        # Per-frame base prediction (if input dims match)
        if len(coords) == model.input_shape[1]:
            coords_array = np.array(coords, dtype=np.float32).reshape(1, -1)
            if norm_mean is not None and norm_std is not None and norm_mean.shape[0] == coords_array.shape[1]:
                coords_array = (coords_array - norm_mean) / (norm_std + 1e-8)
            preds = model.predict(coords_array, verbose=0)
            idx = int(np.argmax(preds))
            if 0 <= idx < len(labels):
                base_label = labels[idx]
                base_label_buffer.append(base_label)
                # display the current base label only when not holding a promoted result
                if hold_counter == 0:
                    latest_char = base_label
        else:
            # dimension mismatch; skip prediction this frame
            pass

    # 글자 출력 (직전 인식 결과)
    if pil_font and latest_char:
        pil_image = Image.fromarray(cv2.cvtColor(image, cv2.COLOR_BGR2RGB))
        draw = ImageDraw.Draw(pil_image)
        draw.text(TEXT_POSITION, latest_char, font=pil_font, fill=TEXT_COLOR_RGB)
        image = cv2.cvtColor(np.array(pil_image), cv2.COLOR_RGB2BGR)
    elif latest_char:
        cv2.putText(image, latest_char, TEXT_POSITION, cv2.FONT_HERSHEY_SIMPLEX, 2, BOX_COLOR_BGR, 3)

    cv2.imshow("Sign Language Capture", image)

    key = cv2.waitKey(10) & 0xFF

    if key == 27:  # ESC
        break
    elif key == 32:  # SPACE
        # Use recent window for decision
        base_major_info = majority_label(list(base_label_buffer))
        base_major = base_major_info[0] if base_major_info else None
        base_frac = base_major_info[1] if base_major_info else 0.0
        final_label = base_major
        if base_major in BASE_TO_TENSE and base_frac >= BASE_MAJORITY_MIN:
            peak_count, peak_idx = count_motion_peaks(list(motion_buffer))
            if peak_count >= MIN_PEAKS:
                final_label = BASE_TO_TENSE[base_major]
        if final_label is None:
            print("🖐️ 손이 인식되지 않았습니다. 다시 시도하세요.")
            latest_char = ""
        else:
            latest_char = final_label
            print(f"🔤 인식 결과: {latest_char} (base={base_major}, frac={base_frac:.2f})")
        # Hold the decision on screen and reset buffers for next window
        hold_counter = DISPLAY_HOLD_FRAMES
        base_label_buffer.clear()
        motion_buffer.clear()
        prev_xy.clear()

    # decrement hold counter each frame
    if hold_counter > 0:
        hold_counter -= 1

cap.release()
cv2.destroyAllWindows()
hands.close()

print("Recognition ended.")
