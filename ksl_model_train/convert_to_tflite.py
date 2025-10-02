import tensorflow as tf
import os
import shutil

def convert_and_copy():
    base_dir = os.path.dirname(__file__)
    model_dir = os.path.join(base_dir, "model")
    
    # H5 모델 경로
    h5_path = os.path.join(model_dir, "ksl_model.h5")
    
    if not os.path.exists(h5_path):
        print(f"❌ H5 파일이 없습니다: {h5_path}")
        return False
    
    try:
        # H5 모델 로드
        model = tf.keras.models.load_model(h5_path)
        print(f"✅ H5 모델 로드 성공")
        
        # TFLite 컨버터 생성
        converter = tf.lite.TFLiteConverter.from_keras_model(model)
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
        
        # TFLite 모델로 변환
        tflite_model = converter.convert()
        
        # TFLite 파일 저장
        tflite_path = os.path.join(model_dir, "ksl_model.tflite")
        with open(tflite_path, 'wb') as f:
            f.write(tflite_model)
        
        print(f"✅ TFLite 변환 완료: {len(tflite_model)} bytes")
        
        # myproject로 복사
        myproject_model_dir = os.path.join(base_dir, "..", "myproject", "model")
        
        if os.path.exists(myproject_model_dir):
            # TFLite 파일 복사
            dest_tflite = os.path.join(myproject_model_dir, "ksl_model.tflite")
            shutil.copy2(tflite_path, dest_tflite)
            
            # 라벨 파일 복사
            labels_src = os.path.join(model_dir, "ksl_labels.npy")
            labels_dest = os.path.join(myproject_model_dir, "ksl_labels.npy")
            if os.path.exists(labels_src):
                shutil.copy2(labels_src, labels_dest)
            
            print(f"✅ 파일들이 myproject/model/로 복사되었습니다")
            return True
        else:
            print(f"❌ myproject/model/ 디렉토리가 없습니다")
            return False
            
    except Exception as e:
        print(f"❌ 변환 실패: {e}")
        return False

if __name__ == "__main__":
    convert_and_copy()
