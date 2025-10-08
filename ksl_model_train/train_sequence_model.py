import os
import numpy as np
import pandas as pd
from sklearn.model_selection import train_test_split
from tensorflow.keras.models import Sequential
from tensorflow.keras.layers import LSTM, Dense, Dropout
from tensorflow.keras.utils import to_categorical
from tensorflow.keras.callbacks import EarlyStopping
from tensorflow.keras.preprocessing.sequence import pad_sequences

# 경로 설정
BASE_DIR = os.path.dirname(__file__)
DATA_DIR = os.path.join(BASE_DIR, "data_seq")
MODEL_DIR = os.path.join(os.path.dirname(BASE_DIR), "myproject", "model")
os.makedirs(MODEL_DIR, exist_ok=True)

# 복합모음 목록 (시퀀스로 표현)
COMPLEX_VOWELS = ['ㅘ', 'ㅙ', 'ㅝ', 'ㅞ', 'ㅢ']  # 연속 동작이 필요한 복합모음

print("=" * 60)
print("시퀀스 모델 학습 (복합모음 연속 동작)")
print("=" * 60)

# 1. 데이터 로딩
def load_sequence_data(label_dir):
    """한 라벨의 모든 시퀀스 CSV 파일 로딩"""
    sequences = []
    csv_files = [f for f in os.listdir(label_dir) if f.endswith('.csv')]
    
    for csv_file in csv_files:
        csv_path = os.path.join(label_dir, csv_file)
        try:
            df = pd.read_csv(csv_path)
            # 프레임별로 그룹화하여 특징 추출
            frames = []
            for frame_id in sorted(df['frame'].unique()):
                frame_data = df[df['frame'] == frame_id]
                # x, y, dx, dy, spd_sum 추출
                features = []
                for _, row in frame_data.iterrows():
                    features.extend([row['x'], row['y'], row['dx'], row['dy']])
                # spd_sum은 프레임당 하나만
                if len(frame_data) > 0:
                    features.append(frame_data.iloc[0]['spd_sum'])
                frames.append(features)
            
            if len(frames) > 0:
                sequences.append(np.array(frames))
        except Exception as e:
            print(f"⚠️  {csv_file} 로딩 실패: {e}")
    
    return sequences

all_sequences = []
all_labels = []

for vowel in COMPLEX_VOWELS:
    label_dir = os.path.join(DATA_DIR, vowel)
    if not os.path.exists(label_dir):
        print(f"⚠️  {vowel} 폴더 없음 (스킵)")
        continue
    
    sequences = load_sequence_data(label_dir)
    if len(sequences) == 0:
        print(f"⚠️  {vowel}: 데이터 없음")
        continue
    
    all_sequences.extend(sequences)
    all_labels.extend([vowel] * len(sequences))
    print(f"✅ {vowel}: {len(sequences)}개 시퀀스")

if len(all_sequences) == 0:
    print("\n❌ 학습 데이터가 없습니다!")
    print(f"   {DATA_DIR} 폴더에 복합모음 시퀀스를 추가하세요.")
    print(f"   사용법: python capture_sequence.py")
    exit(1)

# 2. 시퀀스 패딩 (길이 맞추기)
max_len = max(len(seq) for seq in all_sequences)
feature_dim = all_sequences[0].shape[1]

print(f"\n최대 시퀀스 길이: {max_len} 프레임")
print(f"특징 차원: {feature_dim}")

# 패딩 적용
X = pad_sequences(all_sequences, maxlen=max_len, dtype='float32', padding='post')
y = np.array(all_labels)

print(f"총 샘플 수: {len(X)}")
print(f"입력 shape: {X.shape}")

# 라벨 인코딩
unique_labels = sorted(set(all_labels))
label_to_idx = {label: idx for idx, label in enumerate(unique_labels)}
y_encoded = np.array([label_to_idx[label] for label in y])
y_categorical = to_categorical(y_encoded)

print(f"클래스 수: {len(unique_labels)}")
print(f"클래스: {unique_labels}")

# 3. 학습/테스트 분할
X_train, X_test, y_train, y_test = train_test_split(
    X, y_categorical, test_size=0.2, random_state=42, stratify=y_encoded
)

print(f"\n학습 데이터: {len(X_train)}개")
print(f"테스트 데이터: {len(X_test)}개")

# 4. LSTM 모델 구성
model = Sequential([
    LSTM(128, return_sequences=True, input_shape=(max_len, feature_dim)),
    Dropout(0.3),
    LSTM(64, return_sequences=False),
    Dropout(0.3),
    Dense(32, activation='relu'),
    Dropout(0.2),
    Dense(len(unique_labels), activation='softmax')
])

model.compile(
    optimizer='adam',
    loss='categorical_crossentropy',
    metrics=['accuracy']
)

print("\n모델 구조:")
model.summary()

# 5. 학습
print("\n학습 시작...")
early_stop = EarlyStopping(monitor='val_loss', patience=30, restore_best_weights=True)

history = model.fit(
    X_train, y_train,
    validation_data=(X_test, y_test),
    epochs=200,
    batch_size=16,
    callbacks=[early_stop],
    verbose=1
)

# 6. 평가
test_loss, test_acc = model.evaluate(X_test, y_test, verbose=0)
print(f"\n테스트 정확도: {test_acc * 100:.2f}%")

# 7. 모델 저장
model_path = os.path.join(MODEL_DIR, "ksl_model_sequence.h5")
labels_path = os.path.join(MODEL_DIR, "ksl_labels_sequence.npy")
config_path = os.path.join(MODEL_DIR, "ksl_sequence_config.npy")

model.save(model_path)
np.save(labels_path, np.array(unique_labels))
np.save(config_path, np.array([max_len, feature_dim]))

print(f"\n✅ 모델 저장 완료:")
print(f"   - {model_path}")
print(f"   - {labels_path}")
print(f"   - {config_path}")
print(f"\n학습된 복합모음: {', '.join(unique_labels)}")
