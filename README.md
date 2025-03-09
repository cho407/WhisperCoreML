# WhisperCoreML

WhisperCoreML은 OpenAI의 Whisper 음성 인식 모델을 Swift 및 CoreML을 사용하여 구현한 패키지입니다. 이 패키지를 사용하면 iOS 및 macOS 애플리케이션에서 오프라인으로 고품질 음성 인식 및 번역 기능을 구현할 수 있습니다.

## 특징

- 다양한 크기의 Whisper 모델 지원 (Tiny, Base, Small, Medium, Large)
- 오프라인 음성 인식 및 번역
- 100개 이상의 언어 지원
- 자막 생성 (SRT, VTT 형식)
- 비동기 API (async/await)
- Combine 프레임워크 지원
- 진행 상황 모니터링
- 메모리 및 성능 최적화

## 요구 사항

- iOS 16.0+ / macOS 13.0+
- Swift 5.9+
- Xcode 15.0+

## 설치

### Swift Package Manager

`Package.swift` 파일에 다음과 같이 의존성을 추가하세요:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/WhisperCoreML.git", from: "1.0.0")
]
```

그리고 타겟에 "WhisperCoreML"을 추가하세요:

```swift
.target(
    name: "YourTarget",
    dependencies: ["WhisperCoreML"]
),
```

## 사용 방법

### 기본 사용법

```swift
import WhisperCoreML

// 모델 초기화
let model = WhisperModel(modelType: .tiny)

// 모델 다운로드 (필요한 경우)
try await model.downloadModel { progress in
    print("다운로드 진행률: \(progress * 100)%")
}

// 오디오 파일 변환
let result = try await model.transcribe(
    audioURL: audioFileURL,
    options: .default
) { progress in
    print("변환 진행률: \(progress * 100)%")
}

// 결과 사용
print("변환된 텍스트: \(result.text)")
print("감지된 언어: \(result.detectedLanguage ?? "알 수 없음")")
print("세그먼트 수: \(result.segments.count)")
```

### 변환 옵션 설정

```swift
// 커스텀 옵션 설정
let options = TranscriptionOptions(
    language: "ko",           // 한국어로 설정 (nil로 설정하면 자동 감지)
    task: .translate,         // 영어로 번역
    temperature: 0.3,         // 다양성 조절 (0.0 ~ 1.0)
    compressionRatio: 2.0,    // 압축 비율
    logProbThreshold: -0.7,   // 로그 확률 임계값
    silenceThreshold: 0.5,    // 무음 임계값 (초)
    initialPrompt: "안녕하세요", // 초기 프롬프트
    enableWordTimestamps: true // 단어 수준 타임스탬프 활성화
)

// 옵션을 사용한 변환
let result = try await model.transcribe(
    audioURL: audioFileURL,
    options: options
) { progress in
    print("변환 진행률: \(progress * 100)%")
}
```

### 자막 생성

```swift
import WhisperCoreMLUtils

// 자막 유틸리티 사용
let subtitleUtils = SubtitleUtils.shared

// SRT 파일 생성
try subtitleUtils.createSRTFile(
    segments: result.segments,
    outputURL: srtFileURL
)

// VTT 파일 생성
try subtitleUtils.createVTTFile(
    segments: result.segments,
    outputURL: vttFileURL
)
```

### 모델 관리

```swift
// 모델 정보 확인
let modelInfo = model.getModelInfo()
print("모델 타입: \(modelInfo["model_type"] as? String ?? "")")
print("모델 크기: \(modelInfo["model_size_mb"] as? Int ?? 0) MB")
print("모델 존재 여부: \(modelInfo["model_exists"] as? Bool ?? false)")

// 모델 삭제
try model.deleteModel()
```

## 아키텍처

WhisperCoreML은 다음과 같은 주요 컴포넌트로 구성되어 있습니다:

- **WhisperModel**: 핵심 모델 클래스로, 음성 인식 및 번역 기능을 제공합니다.
- **AudioProcessor**: 오디오 파일 처리 및 전처리를 담당합니다.
- **TranscriptionOptions**: 변환 옵션을 설정합니다.
- **TranscriptionResult**: 변환 결과를 나타냅니다.
- **WhisperModelType**: 지원되는 모델 유형을 정의합니다.
- **SubtitleUtils**: 자막 생성 및 처리 기능을 제공합니다.
- **DownloadManager**: 모델 다운로드를 관리합니다.

## 성능 최적화

WhisperCoreML은 다음과 같은 성능 최적화 기능을 제공합니다:

- **컴퓨팅 유닛 선택**: CPU, GPU 또는 Neural Engine을 선택적으로 사용할 수 있습니다.
- **모델 양자화**: 모델 크기를 줄이고 추론 속도를 향상시킵니다.
- **메모리 사용량 최적화**: 대용량 오디오 파일 처리 시 메모리 사용량을 최적화합니다.
- **배치 처리**: 긴 오디오 파일을 작은 세그먼트로 나누어 처리합니다.

## 라이선스

이 프로젝트는 MIT 라이선스 하에 배포됩니다. 자세한 내용은 [LICENSE](LICENSE) 파일을 참조하세요.

## 기여

기여는 언제나 환영합니다! 버그 리포트, 기능 요청, 풀 리퀘스트 등 모든 형태의 기여를 환영합니다.

## 감사의 말

이 프로젝트는 OpenAI의 [Whisper](https://github.com/openai/whisper) 모델을 기반으로 합니다. Whisper 모델을 개발한 OpenAI 팀에 감사드립니다. 