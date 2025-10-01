import pandas as pd
import numpy as np
import os
from sklearn.preprocessing import LabelEncoder
from tensorflow.keras.models import Sequential
from tensorflow.keras.layers import Dense, Dropout
from tensorflow.keras.utils import to_categorical
from sklearn.model_selection import train_test_split
from tensorflow.keras.callbacks import EarlyStopping

X, y = [], []

# 현재 파일 위치 기준
base_dir = os.path.dirname(__file__)
data_directory = os.path.join(base_dir, "data")

print(f"Reading CSV files from: {os.path.abspath(data_directory)}")

if not os.path.isdir(data_directory):
    print(f"Error: Directory '{data_directory}' not found.")
    exit()

csv_files_found = False
for file in os.listdir(data_directory):
    if file.endswith(".csv"):
        csv_files_found = True
        file_path = os.path.join(data_directory, file)
        print(f"Processing file: {file_path}")
        try:
            df = pd.read_csv(file_path, header=None, encoding='utf-8')
            if df.shape[1] > 1:
                X.extend(df.iloc[:, :-1].values.tolist())
                y.extend(df.iloc[:, -1].values.tolist())
                print(f"  Labels sample from {file}: {df.iloc[:3, -1].unique()}")
            else:
                print(f"  Warning: {file} has only one column. Skipping.")
        except Exception as e:
            print(f"Error reading {file_path}: {e}")
            continue

if not csv_files_found or not X or not y:
    print("No usable data found. Exiting.")
    exit()

print(f"\nTotal samples loaded: {len(X)}")
print(f"Unique labels before encoding: {np.unique(y)}")

X = np.array(X, dtype=np.float32)
le = LabelEncoder()
y_encoded = le.fit_transform(y)
y_cat = to_categorical(y_encoded)

labels_original_order = le.classes_
print(f"Label classes: {labels_original_order}")
print(f"Number of classes: {len(labels_original_order)}")

if len(X) > 1:
    # NOTE: stratify should use class indices, not one-hot vectors.
    X_train, X_val, y_train_cat, y_val_cat = train_test_split(
        X, y_cat, test_size=0.2, stratify=y_encoded, random_state=42
    )
    print(f"\nTraining set size: {X_train.shape[0]}")
    print(f"Validation set size: {X_val.shape[0]}")
else:
    X_train, y_train_cat = X, y_cat
    X_val, y_val_cat = None, None

# === Preprocessing: Standardization (save mean/std for inference) ===
feature_mean = np.mean(X_train, axis=0)
feature_std = np.std(X_train, axis=0) + 1e-8
X_train = (X_train - feature_mean) / feature_std
if X_val is not None:
    X_val = (X_val - feature_mean) / feature_std

# Save normalization stats
base_dir = os.path.dirname(__file__)
output_model_dir = os.path.join(base_dir, "model")
os.makedirs(output_model_dir, exist_ok=True)
np.save(os.path.join(output_model_dir, "ksl_norm_mean.npy"), feature_mean.astype(np.float32))
np.save(os.path.join(output_model_dir, "ksl_norm_std.npy"), feature_std.astype(np.float32))
print("Saved normalization stats to model/ (ksl_norm_mean.npy, ksl_norm_std.npy)")

# === Model: lightweight for Raspberry Pi 3 ===
model = Sequential([
    Dense(64, activation='relu', input_shape=(X_train.shape[1],)),
    Dropout(0.2),
    Dense(32, activation='relu'),
    Dropout(0.2),
    Dense(y_cat.shape[1], activation='softmax')
])
model.compile(optimizer='adam', loss='categorical_crossentropy', metrics=['accuracy'])

early_stopping = EarlyStopping(monitor='val_loss', patience=10, restore_best_weights=True, verbose=1)

if X_val is not None and y_val_cat is not None:
    history = model.fit(
        X_train, y_train_cat,
        epochs=100,
        batch_size=32,
        validation_data=(X_val, y_val_cat),
        callbacks=[early_stopping],
        verbose=1,
    )
else:
    history = model.fit(X_train, y_train_cat, epochs=100, batch_size=32, verbose=1)

# === 모델 저장 ===
model.save(os.path.join(output_model_dir, "ksl_model.h5"))
np.save(os.path.join(output_model_dir, "ksl_labels.npy"), labels_original_order)

print(f"\n모델과 라벨이 '{output_model_dir}' 디렉토리에 저장되었습니다.")
print("ksl_labels.npy 라벨 목록:", labels_original_order)
