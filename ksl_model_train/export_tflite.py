import os
import numpy as np
import tensorflow as tf

# Paths
BASE_DIR = os.path.dirname(__file__)
MODEL_DIR = os.path.join(BASE_DIR, "model")
H5_PATH = os.path.join(MODEL_DIR, "ksl_model.h5")
TFLITE_FP32_PATH = os.path.join(MODEL_DIR, "ksl_model_fp32.tflite")
TFLITE_INT8_PATH = os.path.join(MODEL_DIR, "ksl_model_int8.tflite")
DATA_DIR = os.path.join(BASE_DIR, "data")

# Load model
if not os.path.exists(H5_PATH):
    raise FileNotFoundError(f"Model not found: {H5_PATH}")
model = tf.keras.models.load_model(H5_PATH)

# Representative dataset generator for INT8 calibration
# Uses a few samples from CSVs to estimate activation ranges.
def representative_dataset():
    count = 0
    max_samples = 200  # adjust if needed
    if not os.path.isdir(DATA_DIR):
        return
    for fname in os.listdir(DATA_DIR):
        if not fname.endswith('.csv'):
            continue
        fpath = os.path.join(DATA_DIR, fname)
        try:
            data = np.loadtxt(fpath, delimiter=',', dtype=np.float32)
        except Exception:
            # Fallback: try pandas if different formatting
            try:
                import pandas as pd
                df = pd.read_csv(fpath, header=None, encoding='utf-8')
                data = df.values.astype(np.float32)
            except Exception:
                continue
        if data.ndim == 1:
            data = data.reshape(1, -1)
        # drop last column if it's label
        if data.shape[1] > model.input_shape[1]:
            data = data[:, : model.input_shape[1]]
        for i in range(min(len(data), 20)):
            x = data[i].reshape(1, -1)
            # NOTE: We assume runtime will apply the same normalization as in predict scripts.
            # If you want to bake normalization into calibration, you can load mean/std here.
            yield [x]
            count += 1
            if count >= max_samples:
                return

# Convert FP32
converter = tf.lite.TFLiteConverter.from_keras_model(model)
tflite_model = converter.convert()
with open(TFLITE_FP32_PATH, 'wb') as f:
    f.write(tflite_model)
print(f"Saved FP32 TFLite model: {TFLITE_FP32_PATH}")

# Convert INT8 (full integer quantization)
converter = tf.lite.TFLiteConverter.from_keras_model(model)
converter.optimizations = [tf.lite.Optimize.DEFAULT]
converter.representative_dataset = representative_dataset
# Ensure int8 IO for best CPU performance on Raspberry Pi 3
converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS_INT8]
converter.inference_input_type = tf.int8
converter.inference_output_type = tf.int8

int8_tflite_model = converter.convert()
with open(TFLITE_INT8_PATH, 'wb') as f:
    f.write(int8_tflite_model)
print(f"Saved INT8 TFLite model: {TFLITE_INT8_PATH}")
