import pandas as pd
import numpy as np
import os
from sklearn.preprocessing import LabelEncoder
from sklearn.model_selection import train_test_split
from tensorflow.keras.models import Sequential
from tensorflow.keras.layers import LSTM, Dense, Dropout, Bidirectional
from tensorflow.keras.utils import to_categorical
from tensorflow.keras.callbacks import EarlyStopping
from sklearn.metrics import confusion_matrix, classification_report
import matplotlib.pyplot as plt
import seaborn as sns
import random

# 경로 설정
BASE_DIR = os.path.dirname(__file__)
DATA_SEQ_DIR = os.path.join(BASE_DIR, "data_seq")
OUTPUT_MODEL_DIR = os.path.join(BASE_DIR, "model")
os.makedirs(OUTPUT_MODEL_DIR, exist_ok=True)

print(f"Reading sequence data from: {os.path.abspath(DATA_SEQ_DIR)}")

# 시퀀스 데이터 로드
def load_sequence_data(data_dir):
    """
    data_seq/ 폴더에서 시퀀스 CSV 파일들을 읽어서 3D 배열로 변환
    Returns: X (samples, timesteps, features), y (labels)
    """
    X_sequences = []
    y_labels = []
    
    for label_folder in os.listdir(data_dir):
        label_path = os.path.join(data_dir, label_folder)
        if not os.path.isdir(label_path):
            continue
        
        print(f"Processing label: {label_folder}")
        
        for csv_file in os.listdir(label_path):
            if not csv_file.endswith('.csv'):
                continue
            
            csv_path = os.path.join(label_path, csv_file)
            try:
                df = pd.read_csv(csv_path)
                
                # 프레임별로 그룹화하여 시퀀스 생성
                frames = df['frame'].unique()
                sequence = []
                
                for frame_idx in sorted(frames):
                    frame_data = df[df['frame'] == frame_idx]
                    # 각 프레임의 특징: x, y, dx, dy, spd_sum (landmark별로)
                    features = []
                    for _, row in frame_data.iterrows():
                        features.extend([
                            row['x'], 
                            row['y'], 
                            row['dx'], 
                            row['dy'],
                            row['spd_sum']
                        ])
                    sequence.append(features)
                
                if len(sequence) > 0:
                    X_sequences.append(sequence)
                    y_labels.append(label_folder)
                    
            except Exception as e:
                print(f"  Error reading {csv_file}: {e}")
                continue
        
        print(f"  Loaded {len([y for y in y_labels if y == label_folder])} sequences")
    
    return X_sequences, y_labels

# 데이터 증강 함수들
def augment_speed(sequence, factor_range=(0.8, 1.2)):
    """시퀀스 속도 변경 (프레임 보간/제거)"""
    factor = random.uniform(*factor_range)
    seq_len = len(sequence)
    new_len = max(2, int(seq_len * factor))
    
    # 선형 보간
    indices = np.linspace(0, seq_len - 1, new_len)
    new_sequence = []
    for idx in indices:
        lower = int(np.floor(idx))
        upper = min(int(np.ceil(idx)), seq_len - 1)
        weight = idx - lower
        
        if lower == upper:
            new_sequence.append(sequence[lower])
        else:
            interpolated = [
                sequence[lower][i] * (1 - weight) + sequence[upper][i] * weight
                for i in range(len(sequence[0]))
            ]
            new_sequence.append(interpolated)
    
    return new_sequence

def augment_noise(sequence, noise_level=0.02):
    """랜덤 노이즈 추가"""
    noisy_seq = []
    for frame in sequence:
        noisy_frame = [
            val + random.gauss(0, noise_level) if i < 4 else val  # x,y,dx,dy만 노이즈
            for i, val in enumerate(frame)
        ]
        noisy_seq.append(noisy_frame)
    return noisy_seq

def augment_scale(sequence, scale_range=(0.9, 1.1)):
    """크기 변경 (손 크기 변화 시뮬레이션)"""
    scale = random.uniform(*scale_range)
    scaled_seq = []
    for frame in sequence:
        scaled_frame = [
            val * scale if i % 5 < 2 else val  # x, y만 스케일 (매 5개 특징 중 처음 2개)
            for i, val in enumerate(frame)
        ]
        scaled_seq.append(scaled_frame)
    return scaled_seq

def augment_sequence(sequence):
    """여러 증강 기법 랜덤 적용"""
    aug_seq = sequence.copy()
    
    # 50% 확률로 속도 변경
    if random.random() > 0.5:
        aug_seq = augment_speed(aug_seq)
    
    # 70% 확률로 노이즈 추가
    if random.random() > 0.3:
        aug_seq = augment_noise(aug_seq)
    
    # 50% 확률로 스케일 변경
    if random.random() > 0.5:
        aug_seq = augment_scale(aug_seq)
    
    return aug_seq

# 데이터 로드
X_raw, y_raw = load_sequence_data(DATA_SEQ_DIR)

if not X_raw or not y_raw:
    print("No data found. Exiting.")
    exit()

print(f"\nTotal sequences loaded: {len(X_raw)}")
print(f"Unique labels: {np.unique(y_raw)}")

# 데이터 증강 적용
print("\n=== 데이터 증강 시작 ===")
X_augmented = []
y_augmented = []

# 원본 데이터 추가
X_augmented.extend(X_raw)
y_augmented.extend(y_raw)

# 각 샘플당 3~5개의 증강 버전 생성
augmentation_factor = 4
for i, (seq, label) in enumerate(zip(X_raw, y_raw)):
    for _ in range(augmentation_factor):
        aug_seq = augment_sequence(seq)
        X_augmented.append(aug_seq)
        y_augmented.append(label)

print(f"원본 데이터: {len(X_raw)}개")
print(f"증강 후 데이터: {len(X_augmented)}개 (x{augmentation_factor + 1})")

# 증강된 데이터로 교체
X_raw = X_augmented
y_raw = y_augmented

# 시퀀스 길이 통일 (패딩)
max_timesteps = max(len(seq) for seq in X_raw)
feature_dim = len(X_raw[0][0])  # 첫 번째 시퀀스의 첫 프레임 특징 개수

print(f"Max timesteps: {max_timesteps}")
print(f"Feature dimension: {feature_dim}")

# 패딩 적용 (짧은 시퀀스는 0으로 채움)
X_padded = np.zeros((len(X_raw), max_timesteps, feature_dim), dtype=np.float32)
for i, seq in enumerate(X_raw):
    seq_len = len(seq)
    X_padded[i, :seq_len, :] = seq

# 라벨 인코딩
le = LabelEncoder()
y_encoded = le.fit_transform(y_raw)
y_cat = to_categorical(y_encoded)

labels_original_order = le.classes_
print(f"Label classes: {labels_original_order}")
print(f"Number of classes: {len(labels_original_order)}")

# Train/Validation split
X_train, X_val, y_train_cat, y_val_cat = train_test_split(
    X_padded, y_cat, test_size=0.2, stratify=y_encoded, random_state=42
)

print(f"\nTraining set size: {X_train.shape[0]}")
print(f"Validation set size: {X_val.shape[0]}")

# 정규화 (각 특징별로)
feature_mean = np.mean(X_train.reshape(-1, feature_dim), axis=0)
feature_std = np.std(X_train.reshape(-1, feature_dim), axis=0) + 1e-8

X_train = (X_train - feature_mean) / feature_std
X_val = (X_val - feature_mean) / feature_std

# 정규화 통계 저장
np.save(os.path.join(OUTPUT_MODEL_DIR, "ksl_seq_norm_mean.npy"), feature_mean)
np.save(os.path.join(OUTPUT_MODEL_DIR, "ksl_seq_norm_std.npy"), feature_std)
print("Saved normalization stats (ksl_seq_norm_mean.npy, ksl_seq_norm_std.npy)")

# LSTM 모델 구축 (더 강력한 구조)
model = Sequential([
    Bidirectional(LSTM(128, return_sequences=True), input_shape=(max_timesteps, feature_dim)),
    Dropout(0.4),
    Bidirectional(LSTM(64, return_sequences=True)),
    Dropout(0.4),
    Bidirectional(LSTM(32)),
    Dropout(0.3),
    Dense(64, activation='relu'),
    Dropout(0.3),
    Dense(32, activation='relu'),
    Dropout(0.2),
    Dense(len(labels_original_order), activation='softmax')
])

model.compile(
    optimizer='adam',
    loss='categorical_crossentropy',
    metrics=['accuracy']
)

print("\n=== Model Architecture ===")
model.summary()

# 학습
early_stopping = EarlyStopping(
    monitor='val_loss',
    patience=20,
    restore_best_weights=True,
    verbose=1
)

history = model.fit(
    X_train, y_train_cat,
    epochs=150,
    batch_size=32,
    validation_data=(X_val, y_val_cat),
    callbacks=[early_stopping],
    verbose=1
)

# 모델 저장
model.save(os.path.join(OUTPUT_MODEL_DIR, "ksl_sequence_model.h5"))
np.save(os.path.join(OUTPUT_MODEL_DIR, "ksl_seq_labels.npy"), labels_original_order)
np.save(os.path.join(OUTPUT_MODEL_DIR, "ksl_seq_max_timesteps.npy"), max_timesteps)

print(f"\n모델이 '{OUTPUT_MODEL_DIR}' 디렉토리에 저장되었습니다.")
print("저장된 파일:")
print("  - ksl_sequence_model.h5")
print("  - ksl_seq_labels.npy")
print("  - ksl_seq_max_timesteps.npy")
print("  - ksl_seq_norm_mean.npy")
print("  - ksl_seq_norm_std.npy")

# 성능 분석
print("\n=== 성능 분석 ===")

y_val_pred = model.predict(X_val, verbose=0)
y_val_pred_classes = np.argmax(y_val_pred, axis=1)
y_val_true_classes = np.argmax(y_val_cat, axis=1)

# Classification Report
print("\n[Classification Report]")
report = classification_report(
    y_val_true_classes,
    y_val_pred_classes,
    target_names=labels_original_order,
    digits=4
)
print(report)

report_path = os.path.join(OUTPUT_MODEL_DIR, "seq_classification_report.txt")
with open(report_path, 'w', encoding='utf-8') as f:
    f.write(report)
print(f"Report saved to: {report_path}")

# Confusion Matrix
cm = confusion_matrix(y_val_true_classes, y_val_pred_classes)

plt.figure(figsize=(10, 8))
sns.heatmap(
    cm,
    annot=True,
    fmt='d',
    cmap='Blues',
    xticklabels=labels_original_order,
    yticklabels=labels_original_order,
    cbar_kws={'label': 'Count'}
)
plt.title('Confusion Matrix - Sequence Model (쌍자음/복합모음)', fontsize=14, pad=20)
plt.ylabel('True Label', fontsize=12)
plt.xlabel('Predicted Label', fontsize=12)
plt.xticks(rotation=45, ha='right')
plt.yticks(rotation=0)
plt.tight_layout()

cm_path = os.path.join(OUTPUT_MODEL_DIR, "seq_confusion_matrix.png")
plt.savefig(cm_path, dpi=150, bbox_inches='tight')
print(f"Confusion matrix saved to: {cm_path}")
plt.close()

# Per-class accuracy
print("\n[Per-Class Accuracy]")
class_correct = np.diag(cm)
class_total = np.sum(cm, axis=1)
class_accuracy = class_correct / (class_total + 1e-8)

for label, acc, total in zip(labels_original_order, class_accuracy, class_total):
    correct = int(class_correct[list(labels_original_order).index(label)])
    print(f"  {label}: {acc*100:.2f}% ({correct}/{int(total)} correct)")

print("\n학습 완료!")
