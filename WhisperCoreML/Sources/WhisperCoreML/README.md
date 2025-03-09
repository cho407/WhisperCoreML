# WhisperCoreML

WhisperCoreML은 OpenAI의 Whisper 음성 인식 모델을 CoreML 형식으로 변환하여 iOS, iPadOS, macOS 등 Apple 플랫폼에서 효율적으로 사용할 수 있게 해주는 Swift 라이브러리입니다.

## 폴더 구조

라이브러리는 다음과 같은 모듈로 구성되어 있습니다:

- **[Core](Core/)**: 라이브러리의 핵심 구성 요소 및 공개 API
- **[Models](Models/)**: Whisper 모델 관리 및 처리
- **[Audio](Audio/)**: 오디오 처리 및 변환
- **[Transcription](Transcription/)**: 음성 인식 및 변환
- **[Language](Language/)**: 언어 처리, 토큰화, 번역
- **[Utils](Utils/)**: 성능 최적화 및 유틸리티 함수

## 주요 기능

- 다양한 크기의 Whisper 모델 지원 (tiny, base, small, medium, large)
- 파일 기반 음성 인식
- 실시간 음성 인식
- 99개 언어 지원
- 오디오 번역
- 배치 처리
- 오프라인 사용 지원

## 사용 방법

기본적인 사용 방법은 다음과 같습니다:

```swift
import WhisperCoreML

// 모델 로드
let transcriber = WhisperTranscriber.shared
await transcriber.loadModel(modelType: .tiny)

// 파일 변환
let audioURL = URL(fileURLWithPath: "path/to/audio.mp3")
let result = try await transcriber.transcribe(audioURL: audioURL)

// 결과 사용
print(result.text)
```

각 모듈에 대한 자세한 설명은 해당 폴더의 README.md 파일을 참조하세요. 