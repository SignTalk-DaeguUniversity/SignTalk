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

# 모든 CSV 파일 읽어서 데이터로 변환
# data 디렉토리가 현재 스크립트와 같은 위치에 있다고 가정합니다.
# 만약 다른 경로라면 "data" 부분을 적절히 수정해야 합니다.
base_dir = os.path.dirname(__file__)
data_directory = os.path.join(base_dir, "data")


print(f"Reading CSV files from: {os.path.abspath(data_directory)}")

if not os.path.isdir(data_directory):
    print(f"Error: Directory '{data_directory}' not found. Please make sure it exists and contains your CSV files.")
    exit()

csv_files_found = False
for file in os.listdir(data_directory):
    if file.endswith(".csv"):
        csv_files_found = True
        file_path = os.path.join(data_directory, file)
        print(f"Processing file: {file_path}")
        try:
            # UTF-16 인코딩으로 CSV 파일 읽기
            df = pd.read_csv(file_path, header=None, encoding='utf-8')

            # 데이터와 라벨 분리
            # 마지막 열을 라벨로 사용, 나머지를 데이터로 사용
            if df.shape[1] > 1:  # 열이 최소 2개 이상 있어야 데이터와 라벨 분리 가능
                X.extend(df.iloc[:, :-1].values.tolist())
                y.extend(df.iloc[:, -1].values.tolist())
                # 라벨이 제대로 읽혔는지 샘플 출력 (디버깅용)
                print(f"  Labels sample from {file}: {df.iloc[:3, -1].unique()}")
            else:
                print(
                    f"  Warning: File {file} has only one column. Skipping this file as it cannot be split into data and label.")

        except Exception as e:
            print(f"Error reading or processing file {file_path}: {e}")
            print("  Please ensure the file is a valid CSV and encoded in UTF-16.")
            print("  If it's UTF-16LE or UTF-16BE, you might need to specify 'utf-16-le' or 'utf-16-be'.")
            continue  # 문제가 있는 파일은 건너뛰고 계속 진행

if not csv_files_found:
    print(f"No CSV files found in '{data_directory}'. Please check the directory and file extensions.")
    exit()

if not X or not y:
    print("No data was successfully loaded. Exiting.")
    exit()

print(f"\nTotal samples loaded: {len(X)}")
print(f"Unique labels found before encoding: {np.unique(y)}")

X = np.array(X, dtype=np.float32)
le = LabelEncoder()
y_encoded = le.fit_transform(y)
y_cat = to_categorical(y_encoded)

# 라벨 인코더 클래스 저장 (le.classes_는 원본 라벨 순서를 가짐)
labels_original_order = le.classes_
print(f"LabelEncoder classes (original labels): {labels_original_order}")
print(f"Number of unique classes: {len(labels_original_order)}")

# 데이터셋을 훈련셋과 검증셋으로 분리
if len(X) > 1:
    X_train, X_val, y_train_cat, y_val_cat = train_test_split(
        X, y_cat, test_size=0.2, stratify=y_encoded, random_state=42
    )
    print(f"\nTraining set size: {X_train.shape[0]}")
    print(f"Validation set size: {X_val.shape[0]}")
else:
    print("Not enough data to create a validation set. Using all data for training.")
    X_train, y_train_cat = X, y_cat
    X_val, y_val_cat = None, None

# === Preprocessing: Standardization ===
feature_mean = np.mean(X_train, axis=0)
feature_std = np.std(X_train, axis=0) + 1e-8
X_train = (X_train - feature_mean) / feature_std
if X_val is not None:
    X_val = (X_val - feature_mean) / feature_std

# Save normalization stats
os.makedirs(os.path.join(base_dir, "model"), exist_ok=True)
np.save(os.path.join(base_dir, "model", "asl_norm_mean.npy"), feature_mean.astype(np.float32))
np.save(os.path.join(base_dir, "model", "asl_norm_std.npy"), feature_std.astype(np.float32))
print("Saved normalization stats to model/ (asl_norm_mean.npy, asl_norm_std.npy)")

# 모델 구성 (Dropout 추가)
model = Sequential([
    Dense(128, activation='relu', input_shape=(X_train.shape[1],)),
    Dropout(0.2),
    Dense(64, activation='relu'),
    Dropout(0.2),
    Dense(y_cat.shape[1], activation='softmax')
])

model.compile(optimizer='adam', loss='categorical_crossentropy', metrics=['accuracy'])

# 조기 종료 콜백 설정
early_stopping = EarlyStopping(monitor='val_loss', patience=10, restore_best_weights=True, verbose=1)

# 모델 학습
if X_val is not None and y_val_cat is not None:
    history = model.fit(
        X_train, y_train_cat,
        epochs=100,
        batch_size=32,
        validation_data=(X_val, y_val_cat),
        callbacks=[early_stopping],
        verbose=1
    )
else:
    history = model.fit(X_train, y_train_cat, epochs=100, batch_size=32, verbose=1)

# 모델과 라벨 저장
output_model_dir = os.path.join(base_dir, "model")  # <-- 현재 위치 기준 model/ 폴더

os.makedirs(output_model_dir, exist_ok=True)

model.save(os.path.join(output_model_dir, "asl_model.h5"))
np.save(os.path.join(output_model_dir, "asl_labels.npy"), labels_original_order)

print(f"\n모델과 라벨이 '{output_model_dir}' 디렉토리에 저장되었습니다.")
print("asl_labels.npy 라벨 목록:", labels_original_order)

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
    plt.title('Confusion Matrix - ASL Model', fontsize=16, pad=20)
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

