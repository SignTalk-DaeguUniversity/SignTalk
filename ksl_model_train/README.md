<p>실습환경</p>
<p>python 3.8.10</p>

<p>hand_capture.py 파일이 손 벡터 저장하는 파일</p>
<p>train_model.py 벡터값을 학습시키는 파일</p>
<p>predict_real.py 수어를 하면 벡터값을 찾아서 인식을 해야하는 파일</p>
<p>*.ttf 한글 출력시 필요한 폰트(한글 지원하는 ttf 폰트 파일이면 무관)</p>

<h2>KSL 모델 파이프라인 (데이터 수집 → 학습 → 변환 → 추론)</h2>

<h3>구성 파일</h3>
<ul>
<li><code>hand_capture.py</code> : 카메라로 손 랜드마크를 캡처하여 CSV 저장</li>
<li><code>train_model.py</code> : CSV 학습, 라벨 저장(<code>ksl_labels.npy</code>), 정규화 통계 저장(<code>ksl_norm_mean.npy</code>, <code>ksl_norm_std.npy</code>)</li>
<li><code>predict_real.py</code> : Keras 모델(.h5) 기반 실시간 인식 (PC)</li>
<li><code>export_tflite.py</code> : TFLite 변환(FP32/INT8)</li>
<li><code>predict_tflite.py</code> : TFLite 기반 실시간 인식 (Raspberry Pi 3)</li>
</ul>

<h3>1) 데이터 수집</h3>
<pre><code>python hand_capture.py
</code></pre>
<ul>
<li>프롬프트에 저장할 라벨(예: ㄱ, ㄴ 등)을 입력</li>
<li>스페이스바를 누를 때마다 현재 프레임의 랜드마크(42차원)가 CSV에 누적 저장</li>
<li>ESC로 종료</li>
<li><strong>권장:</strong> 각 라벨당 100~300샘플, 다양한 거리/각도/조명</li>
</ul>

<h3>2) 모델 학습 (라즈베리 파이 3 최적화)</h3>
<pre><code>python train_model.py
</code></pre>
<ul>
<li>입력: <code>data/</code> 내 CSV (마지막 컬럼이 라벨)</li>
<li>출력: <code>model/ksl_model.h5</code>, <code>model/ksl_labels.npy</code>, <code>model/ksl_norm_mean.npy</code>, <code>model/ksl_norm_std.npy</code></li>
<li>모델: 소형 MLP (Dense 64→32, Dropout) / 표준화 적용</li>
</ul>

<h3>3) TFLite 변환 (FP32/INT8)</h3>
<pre><code>python export_tflite.py
</code></pre>
<ul>
<li>출력: <code>model/ksl_model_fp32.tflite</code>, <code>model/ksl_model_int8.tflite</code></li>
<li>INT8은 대표 데이터셋(일부 CSV 샘플)로 교정</li>
</ul>

<h3>4) PC에서 Keras 모델 테스트 (선택)</h3>
<pre><code>python predict_real.py
</code></pre>
<ul>
<li>학습 시 저장된 정규화(평균/표준편차)를 적용해 일관성 보장</li>
</ul>

<h3>5) Raspberry Pi 3에서 TFLite 추론</h3>
<ol>
<li>모델/라벨/정규화 파일 복사
<pre><code>model/ksl_model_int8.tflite (또는 fp32)
model/ksl_labels.npy
model/ksl_norm_mean.npy
model/ksl_norm_std.npy
</code></pre>
</li>
<li><code>tflite_runtime</code> 설치 (예시)
<pre><code>pip install --no-cache-dir --extra-index-url https://google-coral.github.io/py-repo/ tflite_runtime
</code></pre>
</li>
<li>실행
<pre><code>python predict_tflite.py
</code></pre>
</li>
</ol>

<h3>라벨 관리 팁</h3>
<ul>
<li>CSV 파일명(또는 마지막 컬럼의 값)이 라벨로 사용됩니다.</li>
<li><code>model/ksl_labels.npy</code>의 순서가 최종 클래스 인덱스 순서입니다.</li>
<li>라벨 추가/변경 시, 수집 → 재학습 → 재변환 과정을 수행하세요.</li>
</ul>
