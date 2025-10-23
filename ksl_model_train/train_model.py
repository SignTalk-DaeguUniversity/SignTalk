import pandas as pd
import numpy as np
import os
from sklearn.preprocessing import LabelEncoder
from sklearn.metrics import confusion_matrix, classification_report
from tensorflow.keras.models import Sequential
from tensorflow.keras.layers import Dense, Dropout
from tensorflow.keras.utils import to_categorical
from sklearn.model_selection import train_test_split
from tensorflow.keras.callbacks import EarlyStopping
import matplotlib.pyplot as plt
import seaborn as sns

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
y = np.array(y)

print(f"\n✅ 원본 데이터: {len(X)}개")

# === 데이터 증강: 혼동되는 자모 강화 ===
print("\n🔄 데이터 증강 시작...")
# 성능 분석 결과 기반으로 혼동되는 자모 선정
confused_chars = ['ㄹ', 'ㅕ', 'ㅗ', 'ㅜ', 'ㅡ', 'ㅣ', 'ㅔ', 'ㅐ', 'ㄷ', 'ㅌ']
augment_factor = 5  # 5배 증강

X_aug = []
y_aug = []

for i, label in enumerate(y):
    X_aug.append(X[i])
    y_aug.append(label)
    
    # 혼동되는 자모 증강
    if label in confused_chars:
        for j in range(augment_factor - 1):
            # 다양한 증강 기법 적용
            aug_data = X[i].copy()
            
            # 1. 노이즈 추가
            noise = np.random.normal(0, 0.01, aug_data.shape)
            aug_data = aug_data + noise
            
            # 2. 스케일 변경 (손 크기 변화)
            scale = np.random.uniform(0.95, 1.05)
            aug_data = aug_data * scale
            
            # 3. 약간의 회전 효과 (좌표 변환)
            if j % 2 == 0:
                angle = np.random.uniform(-0.05, 0.05)
                # 간단한 회전 근사
                aug_data = aug_data + np.random.normal(0, 0.008, aug_data.shape)
            
            X_aug.append(aug_data)
            y_aug.append(label)

X = np.array(X_aug, dtype=np.float32)
y = np.array(y_aug)

print(f"✅ 증강 후 데이터: {len(X)}개")
for char in confused_chars:
    count = sum(y == char)
    print(f"   {char}: {count}개")

le = LabelEncoder()
y_encoded = le.fit_transform(y)
y_cat = to_categorical(y_encoded)

labels_original_order = le.classes_
print(f"\nLabel classes: {labels_original_order}")
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

# === Model: Enhanced architecture for better accuracy ===
model = Sequential([
    Dense(256, activation='relu', input_shape=(X_train.shape[1],)),
    Dropout(0.4),
    Dense(128, activation='relu'),
    Dropout(0.3),
    Dense(64, activation='relu'),
    Dropout(0.3),
    Dense(32, activation='relu'),
    Dropout(0.2),
    Dense(y_cat.shape[1], activation='softmax')
])

# 학습률 조정
from tensorflow.keras.optimizers import Adam
optimizer = Adam(learning_rate=0.001)
model.compile(optimizer=optimizer, loss='categorical_crossentropy', metrics=['accuracy'])

early_stopping = EarlyStopping(monitor='val_loss', patience=15, restore_best_weights=True, verbose=1)

if X_val is not None and y_val_cat is not None:
    history = model.fit(
        X_train, y_train_cat,
        epochs=150,
        batch_size=64,
        validation_data=(X_val, y_val_cat),
        callbacks=[early_stopping],
        verbose=1,
    )
else:
    history = model.fit(X_train, y_train_cat, epochs=150, batch_size=64, verbose=1)

# === 모델 저장 ===
model.save(os.path.join(output_model_dir, "ksl_model.h5"))
np.save(os.path.join(output_model_dir, "ksl_labels.npy"), labels_original_order)

print(f"\n모델과 라벨이 '{output_model_dir}' 디렉토리에 저장되었습니다.")
print("ksl_labels.npy 라벨 목록:", labels_original_order)

# === 성능 분석 ===
if X_val is not None and y_val_cat is not None:
    print("\n=== 성능 분석 시작 ===")
    
    # Validation set 예측
    y_val_pred = model.predict(X_val, verbose=0)
    y_val_pred_classes = np.argmax(y_val_pred, axis=1)
    y_val_true_classes = np.argmax(y_val_cat, axis=1)
    
    # 1. Classification Report
    print("\n[Classification Report]")
    report = classification_report(
        y_val_true_classes, 
        y_val_pred_classes, 
        target_names=labels_original_order,
        digits=4
    )
    print(report)
    
    # Save report to file
    report_path = os.path.join(output_model_dir, "classification_report.txt")
    with open(report_path, 'w', encoding='utf-8') as f:
        f.write(report)
    print(f"Classification report saved to: {report_path}")
    
    # 2. Confusion Matrix
    print("\n[Confusion Matrix]")
    cm = confusion_matrix(y_val_true_classes, y_val_pred_classes)
    
    # Plot confusion matrix
    plt.figure(figsize=(12, 10))
    sns.heatmap(
        cm, 
        annot=True, 
        fmt='d', 
        cmap='Blues',
        xticklabels=labels_original_order,
        yticklabels=labels_original_order,
        cbar_kws={'label': 'Count'}
    )
    plt.title('Confusion Matrix - KSL Model', fontsize=16, pad=20)
    plt.ylabel('True Label', fontsize=12)
    plt.xlabel('Predicted Label', fontsize=12)
    plt.xticks(rotation=45, ha='right')
    plt.yticks(rotation=0)
    plt.tight_layout()
    
    cm_path = os.path.join(output_model_dir, "confusion_matrix.png")
    plt.savefig(cm_path, dpi=150, bbox_inches='tight')
    print(f"Confusion matrix saved to: {cm_path}")
    plt.close()
    
    # 3. Find most confused pairs
    print("\n[Most Confused Label Pairs (Top 10)]")
    confused_pairs = []
    for i in range(len(labels_original_order)):
        for j in range(len(labels_original_order)):
            if i != j and cm[i, j] > 0:
                confused_pairs.append((
                    labels_original_order[i],
                    labels_original_order[j],
                    cm[i, j]
                ))
    
    confused_pairs.sort(key=lambda x: x[2], reverse=True)
    for true_label, pred_label, count in confused_pairs[:10]:
        print(f"  {true_label} → {pred_label}: {count} times")
    
    # 4. Per-class accuracy
    print("\n[Per-Class Accuracy]")
    class_correct = np.diag(cm)
    class_total = np.sum(cm, axis=1)
    class_accuracy = class_correct / (class_total + 1e-8)
    
    acc_data = list(zip(labels_original_order, class_accuracy, class_total))
    acc_data.sort(key=lambda x: x[1])  # Sort by accuracy
    
    print("Lowest accuracy labels:")
    for label, acc, total in acc_data[:5]:
        print(f"  {label}: {acc*100:.2f}% ({int(class_correct[list(labels_original_order).index(label)])}/{int(total)} correct)")
    
    print("\n성능 분석 완료!")
else:
    print("\nValidation set이 없어 성능 분석을 건너뜁니다.")
