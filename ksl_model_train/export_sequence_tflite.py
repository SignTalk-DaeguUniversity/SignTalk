"""
시퀀스 모델 (Bidirectional LSTM) TFLite 변환 스크립트
라즈베리파이 3 및 임베디드 환경 최적화
"""
import os
import numpy as np
import tensorflow as tf

# 경로 설정
BASE_DIR = os.path.dirname(__file__)
MODEL_DIR = os.path.join(BASE_DIR, "model")
H5_PATH = os.path.join(MODEL_DIR, "ksl_sequence_model.h5")
TFLITE_FP32_PATH = os.path.join(MODEL_DIR, "ksl_sequence_fp32.tflite")
TFLITE_FP16_PATH = os.path.join(MODEL_DIR, "ksl_sequence_fp16.tflite")
DATA_SEQ_DIR = os.path.join(BASE_DIR, "data_seq")

print("="*60)
print("🔄 시퀀스 모델 TFLite 변환 시작")
print("="*60)

# 모델 로드
if not os.path.exists(H5_PATH):
    raise FileNotFoundError(f"❌ 모델을 찾을 수 없습니다: {H5_PATH}")

print(f"✅ 모델 로드 중: {H5_PATH}")
model = tf.keras.models.load_model(H5_PATH)
print(f"   입력 shape: {model.input_shape}")
print(f"   출력 shape: {model.output_shape}")

# 대표 데이터셋 생성 (양자화 교정용)
def representative_dataset():
    """
    시퀀스 데이터에서 샘플을 추출하여 양자화 교정에 사용
    """
    count = 0
    max_samples = 100
    
    if not os.path.isdir(DATA_SEQ_DIR):
        print("⚠️  data_seq 폴더가 없습니다. 교정 없이 변환합니다.")
        return
    
    print("\n📊 대표 데이터셋 생성 중...")
    
    for label_folder in os.listdir(DATA_SEQ_DIR):
        label_path = os.path.join(DATA_SEQ_DIR, label_folder)
        if not os.path.isdir(label_path):
            continue
        
        for csv_file in os.listdir(label_path):
            if not csv_file.endswith('.csv'):
                continue
            
            csv_path = os.path.join(label_path, csv_file)
            try:
                import pandas as pd
                df = pd.read_csv(csv_path)
                
                # 프레임별로 시퀀스 생성
                frames = df['frame'].unique()
                sequence = []
                
                for frame_idx in sorted(frames):
                    frame_data = df[df['frame'] == frame_idx]
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
                    # 패딩 적용
                    max_timesteps = model.input_shape[1]
                    feature_dim = model.input_shape[2]
                    
                    padded_seq = np.zeros((1, max_timesteps, feature_dim), dtype=np.float32)
                    seq_len = min(len(sequence), max_timesteps)
                    padded_seq[0, :seq_len, :] = sequence[:seq_len]
                    
                    # 정규화 적용
                    norm_mean_path = os.path.join(MODEL_DIR, "ksl_seq_norm_mean.npy")
                    norm_std_path = os.path.join(MODEL_DIR, "ksl_seq_norm_std.npy")
                    
                    if os.path.exists(norm_mean_path) and os.path.exists(norm_std_path):
                        norm_mean = np.load(norm_mean_path)
                        norm_std = np.load(norm_std_path)
                        padded_seq = (padded_seq - norm_mean) / norm_std
                    
                    yield [padded_seq]
                    count += 1
                    
                    if count >= max_samples:
                        print(f"   ✅ {count}개 샘플 생성 완료")
                        return
                    
            except Exception as e:
                continue
    
    print(f"   ✅ {count}개 샘플 생성 완료")

# 1. FP32 변환 (기본)
print("\n" + "="*60)
print("🔧 FP32 TFLite 변환 중...")
print("="*60)

converter = tf.lite.TFLiteConverter.from_keras_model(model)
tflite_model = converter.convert()

with open(TFLITE_FP32_PATH, 'wb') as f:
    f.write(tflite_model)

fp32_size = os.path.getsize(TFLITE_FP32_PATH) / 1024 / 1024
print(f"✅ FP32 모델 저장 완료: {TFLITE_FP32_PATH}")
print(f"   크기: {fp32_size:.2f} MB")

# 2. FP16 변환 (권장: 크기 1/2, 정확도 유지)
print("\n" + "="*60)
print("🔧 FP16 TFLite 변환 중 (권장)...")
print("="*60)

converter = tf.lite.TFLiteConverter.from_keras_model(model)
converter.optimizations = [tf.lite.Optimize.DEFAULT]
converter.target_spec.supported_types = [tf.float16]

fp16_tflite_model = converter.convert()

with open(TFLITE_FP16_PATH, 'wb') as f:
    f.write(fp16_tflite_model)

fp16_size = os.path.getsize(TFLITE_FP16_PATH) / 1024 / 1024
print(f"✅ FP16 모델 저장 완료: {TFLITE_FP16_PATH}")
print(f"   크기: {fp16_size:.2f} MB")
print(f"   압축률: {(1 - fp16_size/fp32_size)*100:.1f}%")

# 3. INT8 변환 시도 (LSTM은 제한적 지원)
print("\n" + "="*60)
print("🔧 INT8 TFLite 변환 시도 (실험적)...")
print("="*60)
print("⚠️  주의: Bidirectional LSTM은 INT8 양자화 시 일부 연산이 FP32로 폴백될 수 있습니다.")

try:
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    converter.representative_dataset = representative_dataset
    
    # LSTM은 완전한 INT8 지원이 어려우므로 유연한 설정 사용
    converter.target_spec.supported_ops = [
        tf.lite.OpsSet.TFLITE_BUILTINS,  # 기본 연산
        tf.lite.OpsSet.SELECT_TF_OPS     # TensorFlow 연산 폴백 허용
    ]
    
    int8_tflite_model = converter.convert()
    
    int8_path = os.path.join(MODEL_DIR, "ksl_sequence_int8.tflite")
    with open(int8_path, 'wb') as f:
        f.write(int8_tflite_model)
    
    int8_size = os.path.getsize(int8_path) / 1024 / 1024
    print(f"✅ INT8 모델 저장 완료: {int8_path}")
    print(f"   크기: {int8_size:.2f} MB")
    print(f"   압축률: {(1 - int8_size/fp32_size)*100:.1f}%")
    print("   ⚠️  일부 LSTM 연산은 FP32로 실행될 수 있습니다.")
    
except Exception as e:
    print(f"❌ INT8 변환 실패: {e}")
    print("   → FP16 모델 사용을 권장합니다.")

# 요약
print("\n" + "="*60)
print("📊 변환 결과 요약")
print("="*60)
print(f"원본 H5 모델: {os.path.getsize(H5_PATH) / 1024 / 1024:.2f} MB")
print(f"FP32 TFLite: {fp32_size:.2f} MB")
print(f"FP16 TFLite: {fp16_size:.2f} MB (권장)")
print("\n💡 권장 사항:")
print("   - 라즈베리파이 3/4: FP16 모델 사용")
print("   - 정확도 우선: FP32 모델 사용")
print("   - 크기/속도 우선: FP16 모델 사용 (정확도 손실 거의 없음)")
print("\n✅ 변환 완료!")
