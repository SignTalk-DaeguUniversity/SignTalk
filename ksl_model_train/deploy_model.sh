#!/bin/bash

# 모델 배포 스크립트
# 학습된 모델을 백엔드로 자동 복사

echo "모델 배포 시작"

SOURCE_DIR="./model"
TARGET_DIR="../myproject/model"

# 백엔드 model 폴더 확인
if [ ! -d "$TARGET_DIR" ]; then
    echo "❌ 백엔드 model 폴더가 없습니다: $TARGET_DIR"
    exit 1
fi

# 정적 모델 복사 (기본 자음/모음)
echo "📦 정적 모델 복사 중..."
cp "$SOURCE_DIR/ksl_model.h5" "$TARGET_DIR/" && echo "  ✅ ksl_model.h5"
cp "$SOURCE_DIR/ksl_labels.npy" "$TARGET_DIR/" && echo "  ✅ ksl_labels.npy"
cp "$SOURCE_DIR/ksl_norm_mean.npy" "$TARGET_DIR/" && echo "  ✅ ksl_norm_mean.npy"
cp "$SOURCE_DIR/ksl_norm_std.npy" "$TARGET_DIR/" && echo "  ✅ ksl_norm_std.npy"

# 시퀀스 모델 복사 (쌍자음/복합모음)
if [ -f "$SOURCE_DIR/ksl_sequence_model.h5" ]; then
    echo "📦 시퀀스 모델 복사 중..."
    cp "$SOURCE_DIR/ksl_sequence_model.h5" "$TARGET_DIR/ksl_model_sequence.h5" && echo "  ✅ ksl_model_sequence.h5"
    cp "$SOURCE_DIR/ksl_seq_labels.npy" "$TARGET_DIR/ksl_labels_sequence.npy" && echo "  ✅ ksl_labels_sequence.npy"
    cp "$SOURCE_DIR/ksl_seq_max_timesteps.npy" "$TARGET_DIR/ksl_sequence_config.npy" && echo "  ✅ ksl_sequence_config.npy"
    cp "$SOURCE_DIR/ksl_seq_norm_mean.npy" "$TARGET_DIR/" && echo "  ✅ ksl_seq_norm_mean.npy"
    cp "$SOURCE_DIR/ksl_seq_norm_std.npy" "$TARGET_DIR/" && echo "  ✅ ksl_seq_norm_std.npy"
else
    echo "!!!!!!!!!!!!!!!!!!!!시퀀스 모델이 없습니다!!!!!!!!"
fi

echo ""
echo "모델 배포 완료!"
echo "배포 위치: $TARGET_DIR"
echo ""
echo "백엔드 서버를 재시작하세요."
echo "   cd ../myproject && python app.py"
