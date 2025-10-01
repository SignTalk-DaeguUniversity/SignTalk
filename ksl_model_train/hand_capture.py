import cv2
import mediapipe as mp
import csv
import os

# 현재 파일 기준으로 저장 디렉토리 고정
base_dir = os.path.dirname(__file__)
data_dir = os.path.join(base_dir, "data")
os.makedirs(data_dir, exist_ok=True)

# 라벨 입력 검증(빈값/공백 방지)
label = ""
while not label.strip():
    label = input("저장할 글자 (예: ㄱ, ㄴ): ").strip()

# 데이터 저장 경로
csv_file = os.path.join(data_dir, f"{label}.csv")

mp_hands = mp.solutions.hands
hands = mp_hands.Hands(
    static_image_mode=False,
    max_num_hands=1,
    min_detection_confidence=0.5,
    min_tracking_confidence=0.5,
)
mp_draw = mp.solutions.drawing_utils

cap = cv2.VideoCapture(0)
if not cap.isOpened():
    print("Error: Could not open webcam.")
    raise SystemExit(1)

# 현재 저장된 샘플 수 세기
def count_existing_rows(path: str) -> int:
    if not os.path.exists(path):
        return 0
    try:
        with open(path, "r", encoding="utf-8") as rf:
            return sum(1 for _ in rf)
    except Exception:
        return 0

saved_count = count_existing_rows(csv_file)

with open(csv_file, 'a', newline='', encoding='utf-8') as f:
    writer = csv.writer(f)

    print("스페이스바: 현재 프레임 저장 | ESC: 종료")
    print(f"현재 라벨 '{label}' 기존 샘플 수: {saved_count}")

    while cap.isOpened():
        ret, frame = cap.read()
        if not ret:
            print("Error: Failed to capture frame.")
            break

        image = cv2.flip(frame, 1)
        rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
        result = hands.process(rgb)

        if result.multi_hand_landmarks:
            for hand_landmarks in result.multi_hand_landmarks:
                mp_draw.draw_landmarks(image, hand_landmarks, mp_hands.HAND_CONNECTIONS)

        # 화면 좌상단에 라벨/카운트 표시
        info_text = f"Label: {label} | Saved: {saved_count}"
        cv2.putText(image, info_text, (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 255, 0), 2)

        cv2.imshow("Hand Capture (KSL)", image)

        key = cv2.waitKey(10) & 0xFF
        if key == 27:  # ESC
            break
        elif key == 32:  # 스페이스바
            if result.multi_hand_landmarks:
                coords = []
                for lm in result.multi_hand_landmarks[0].landmark:
                    coords.extend([lm.x, lm.y])  # 21 * 2 = 42 특징
                coords.append(label)
                try:
                    writer.writerow(coords)
                    saved_count += 1
                    print(f"저장 완료 (총 {saved_count}개)")
                except Exception as e:
                    print(f"저장 실패: {e}")
            else:
                print("손이 인식되지 않았습니다.")

cap.release()
cv2.destroyAllWindows()

