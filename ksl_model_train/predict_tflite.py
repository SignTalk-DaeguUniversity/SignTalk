import os
import sys
import numpy as np
import cv2
import mediapipe as mp

# Prefer tflite_runtime on Raspberry Pi; fall back to tf.lite.Interpreter if available
try:
    from tflite_runtime.interpreter import Interpreter
except Exception:
    try:
        from tensorflow.lite.python.interpreter import Interpreter  # type: ignore
    except Exception as e:
        print("Error: Could not import TFLite Interpreter.", e)
        sys.exit(1)

BASE_DIR = os.path.dirname(__file__)
MODEL_DIR = os.path.join(BASE_DIR, "model")
TFLITE_INT8 = os.path.join(MODEL_DIR, "ksl_model_int8.tflite")
TFLITE_FP32 = os.path.join(MODEL_DIR, "ksl_model_fp32.tflite")
LABELS_PATH = os.path.join(MODEL_DIR, "ksl_labels.npy")
NORM_MEAN_PATH = os.path.join(MODEL_DIR, "ksl_norm_mean.npy")
NORM_STD_PATH = os.path.join(MODEL_DIR, "ksl_norm_std.npy")

# Load labels and normalization
if not os.path.exists(LABELS_PATH):
    print(f"Missing labels: {LABELS_PATH}")
    sys.exit(1)
labels = np.load(LABELS_PATH, allow_pickle=True)
norm_mean = np.load(NORM_MEAN_PATH)
norm_std = np.load(NORM_STD_PATH)

# Choose model
model_path = TFLITE_INT8 if os.path.exists(TFLITE_INT8) else TFLITE_FP32
if not os.path.exists(model_path):
    print("No TFLite model found. Run export_tflite.py first.")
    sys.exit(1)
print(f"Using TFLite model: {model_path}")

# Setup interpreter
interpreter = Interpreter(model_path=model_path, num_threads=2)
interpreter.allocate_tensors()
input_details = interpreter.get_input_details()
output_details = interpreter.get_output_details()

# Input dtype and quantization params
input_dtype = input_details[0]["dtype"]
input_scale = input_details[0].get("quantization_parameters", {}).get("scales", [1.0])
input_zero_point = input_details[0].get("quantization_parameters", {}).get("zero_points", [0])
if isinstance(input_scale, np.ndarray) and input_scale.size > 0:
    input_scale = float(input_scale[0])
if isinstance(input_zero_point, np.ndarray) and input_zero_point.size > 0:
    input_zero_point = int(input_zero_point[0])

# Mediapipe setup
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
    sys.exit(1)

print("Press SPACE to recognize, ESC to exit.")
latest_char = ""

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

    if latest_char:
        cv2.putText(image, str(latest_char), (50, 40), cv2.FONT_HERSHEY_SIMPLEX, 1.2, (0, 0, 255), 3)

    cv2.imshow("KSL TFLite Inference", image)
    key = (cv2.waitKey(10) & 0xFF)

    if key == 27:  # ESC
        break
    elif key == 32:  # SPACE
        if result.multi_hand_landmarks:
            lm_list = result.multi_hand_landmarks[0].landmark
            coords = []
            for lm in lm_list:
                coords.extend([lm.x, lm.y])

            # Normalize same as training
            x = np.array(coords, dtype=np.float32).reshape(1, -1)
            if norm_mean.shape[0] == x.shape[1]:
                x = (x - norm_mean) / (norm_std + 1e-8)

            # Quantize if necessary
            if input_dtype == np.int8:
                x_q = x / input_scale + input_zero_point
                x_q = np.clip(np.round(x_q), -128, 127).astype(np.int8)
                interpreter.set_tensor(input_details[0]["index"], x_q)
            else:
                interpreter.set_tensor(input_details[0]["index"], x.astype(input_dtype))

            interpreter.invoke()
            output_data = interpreter.get_tensor(output_details[0]["index"])  # shape [1, num_classes]
            # Dequantization is handled by Interpreter for outputs when reading get_tensor; dtype is float32 typically
            probs = output_data.reshape(-1)
            idx = int(np.argmax(probs))
            if 0 <= idx < len(labels):
                latest_char = labels[idx]
                print(f"Pred: {latest_char} (idx={idx})")
            else:
                latest_char = "ERR"
                print("Index out of range")
        else:
            print("No hand detected.")

cap.release()
cv2.destroyAllWindows()
hands.close()
print("Done.")
