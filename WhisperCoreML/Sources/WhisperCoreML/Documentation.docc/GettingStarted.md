# WhisperCoreML 시작하기

WhisperCoreML을 사용하여 음성 인식 및 번역 기능을 앱에 통합하는 방법을 알아보세요.

## 개요

WhisperCoreML은 OpenAI의 Whisper 모델을 CoreML 프레임워크를 통해 iOS 및 macOS 앱에서 사용할 수 있게 해주는 라이브러리입니다. 이 라이브러리를 사용하면 오프라인 환경에서도 고품질의 음성 인식 및 번역 기능을 구현할 수 있습니다.

## 설치 방법

### Swift Package Manager

WhisperCoreML은 Swift Package Manager를 통해 설치할 수 있습니다. `Package.swift` 파일에 다음과 같이 의존성을 추가하세요:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/WhisperCoreML.git", from: "1.0.0")
]
```

그리고 타겟에 의존성을 추가하세요:

```swift
.target(
    name: "YourTarget",
    dependencies: ["WhisperCoreML"]
)
```

## 기본 사용법

### 모델 초기화 및 로드

```swift
import WhisperCoreML

// 모델 초기화
let model = try WhisperModel(modelType: .tiny)

// 모델 로드
try await model.loadModel()
```

### 오디오 파일 변환

```swift
// 오디오 파일 URL
let audioURL = URL(fileURLWithPath: "/path/to/audio.mp3")

// 변환 옵션 설정
let options = TranscriptionOptions(
    language: "ko", // 언어 코드 (nil로 설정하면 자동 감지)
    task: .transcribe // 변환 작업 (transcribe 또는 translate)
)

// 변환 실행
let result = try await model.transcribe(
    audioURL: audioURL,
    options: options
) { progress in
    print("변환 진행률: \(progress * 100)%")
}

// 결과 출력
print("변환 결과: \(result.text)")
print("감지된 언어: \(result.detectedLanguage ?? "알 수 없음")")
print("처리 시간: \(result.processingTime)초")

// 세그먼트별 출력
for segment in result.segments {
    print("[\(segment.start) - \(segment.end)] \(segment.text)")
}
```

### 오디오 번역

```swift
// 번역 옵션 설정
let translationOptions = TranslationOptions(
    targetLanguage: "en", // 대상 언어 코드
    quality: 0.8 // 번역 품질 (0.0 ~ 1.0)
)

// 번역 실행
let translationResult = try await model.translateAudio(
    audioURL,
    options: translationOptions
) { progress in
    print("번역 진행률: \(progress * 100)%")
}

// 결과 출력
print("원본 텍스트: \(translationResult.originalText)")
print("번역된 텍스트: \(translationResult.translatedText)")
print("원본 언어: \(translationResult.sourceLanguage)")
print("대상 언어: \(translationResult.targetLanguage)")
```

### 배치 처리

여러 오디오 파일을 배치로 처리하려면 `BatchProcessor` 클래스를 사용하세요:

```swift
// 배치 처리기 초기화
let batchProcessor = BatchProcessor(model: model)

// 처리할 파일 URL 배열
let audioURLs = [
    URL(fileURLWithPath: "/path/to/audio1.mp3"),
    URL(fileURLWithPath: "/path/to/audio2.mp3"),
    URL(fileURLWithPath: "/path/to/audio3.mp3")
]

// 배치 처리 실행
let results = try await batchProcessor.processBatch(urls: audioURLs) { status in
    print("처리 중인 파일: \(status.currentFile)")
    print("전체 진행률: \(status.progress * 100)%")
    print("남은 예상 시간: \(status.estimatedTimeRemaining ?? 0)초")
}

// 결과 출력
for result in results {
    print("파일: \(result.fileURL.lastPathComponent)")
    print("변환 결과: \(result.transcription)")
    print("감지된 언어: \(result.language ?? "알 수 없음")")
    print("오류: \(result.error?.localizedDescription ?? "없음")")
    print("---")
}
```

## 고급 기능

### 메모리 관리

메모리 사용량을 모니터링하고 관리하려면 `MemoryManager` 클래스를 사용하세요:

```swift
// 메모리 관리자 초기화
let memoryManager = MemoryManager.shared

// 메모리 사용량 임계값 설정
memoryManager.setMemoryWarningThreshold(0.8) // 사용 가능한 메모리의 80%

// 메모리 경고 콜백 설정
memoryManager.onMemoryWarning = { usedPercentage in
    print("메모리 경고: 사용량 \(usedPercentage * 100)%")
    // 메모리 확보 작업 수행
}

// 메모리 사용량 확인
let memoryInfo = memoryManager.getMemoryInfo()
print("사용 중인 메모리: \(memoryInfo.usedMemory) MB")
print("사용 가능한 메모리: \(memoryInfo.availableMemory) MB")
print("총 메모리: \(memoryInfo.totalMemory) MB")
```

### 네트워크 모니터링

네트워크 상태를 모니터링하려면 `NetworkMonitor` 클래스를 사용하세요:

```swift
// 네트워크 모니터 시작
NetworkMonitor.startMonitorIfNeeded()

// 네트워크 상태 확인
let isNetworkAvailable = NetworkMonitor.isNetworkAvailable()
let networkType = NetworkMonitor.currentNetworkType

// 네트워크 상태 변경 콜백 설정
NetworkMonitor.onNetworkStatusChanged = { isAvailable, networkType in
    print("네트워크 상태 변경: \(isAvailable ? "사용 가능" : "사용 불가")")
    print("네트워크 유형: \(networkType)")
}
```

### 모델 메타데이터 관리

모델 메타데이터를 관리하려면 `ModelMetadataManager` 클래스를 사용하세요:

```swift
// 메타데이터 관리자 가져오기
let metadataManager = ModelMetadataManager.shared

// 모델 메타데이터 가져오기
if let metadata = metadataManager.getMetadata(for: .tiny) {
    print("모델 버전: \(metadata.version)")
    print("마지막 사용 날짜: \(metadata.lastUsedDate)")
    print("사용 횟수: \(metadata.usageCount)")
    print("평균 처리 시간: \(metadata.averageProcessingTime)초")
    print("지원하는 언어: \(metadata.supportedLanguages.joined(separator: ", "))")
}

// 모델 사용 기록
metadataManager.recordModelUsage(modelType: .tiny, processingTime: 5.2)

// 모든 모델 메타데이터 가져오기
let allMetadata = metadataManager.getAllMetadata()
for metadata in allMetadata {
    print("모델: \(metadata.modelType.displayName)")
    print("사용 횟수: \(metadata.usageCount)")
}
```

## 오류 처리

WhisperCoreML은 다양한 오류 상황을 처리하기 위한 `WhisperError` 열거형을 제공합니다:

```swift
do {
    let result = try await model.transcribe(audioURL: audioURL)
    // 성공적인 처리
} catch let error as WhisperError {
    switch error {
    case .modelNotFound:
        print("모델을 찾을 수 없습니다.")
    case .modelLoadingFailed(let underlyingError):
        print("모델 로드 실패: \(underlyingError.localizedDescription)")
    case .audioProcessingFailed(let reason):
        print("오디오 처리 실패: \(reason)")
    case .networkUnavailable:
        print("네트워크에 연결할 수 없습니다.")
    case .insufficientDiskSpace:
        print("디스크 공간이 부족합니다.")
    case .modelUnavailableOffline(let requested, let alternative):
        if let alt = alternative {
            print("요청한 모델(\(requested.displayName))은 오프라인에서 사용할 수 없습니다. 대신 \(alt.displayName) 모델을 사용할 수 있습니다.")
        } else {
            print("요청한 모델은 오프라인에서 사용할 수 없습니다.")
        }
    default:
        print("오류 발생: \(error.localizedDescription)")
        print("복구 제안: \(error.recoverySuggestion ?? "없음")")
    }
    
    // 오류 복구 옵션 확인
    let recoveryOptions = error.recoveryOptions
    if recoveryOptions.canRetry {
        print("재시도 가능: \(recoveryOptions.message)")
    }
    
    // 오류 로깅
    ErrorLogger.log(error, level: .error)
} catch {
    print("알 수 없는 오류: \(error.localizedDescription)")
}
```

## 성능 최적화

성능을 최적화하려면 다음 기법을 사용하세요:

### 모델 크기 선택

사용 사례에 맞는 적절한 모델 크기를 선택하세요:

- **tiny**: 가장 작고 빠르지만 정확도가 낮음 (약 75MB)
- **base**: 균형 잡힌 성능 (약 142MB)
- **small**: 좋은 정확도와 합리적인 크기 (약 466MB)
- **medium**: 높은 정확도 (약 1.5GB)
- **large**: 최고의 정확도 (약 3GB)
- **largeV2**: large 모델의 개선 버전, 더 높은 정확도 (약 3GB)
- **largeV3**: 최신 버전, 가장 높은 정확도 (약 3GB)

### 배치 크기 조정

`BatchProcessor`의 `maxConcurrentProcessing` 매개변수를 조정하여 동시 처리 수를 제어하세요:

```swift
// 동시에 최대 4개의 파일 처리
let batchProcessor = BatchProcessor(model: model, maxConcurrentProcessing: 4)
```

### 메모리 최적화

긴 오디오 파일을 처리할 때는 최적화된 변환 메서드를 사용하세요:

```swift
// 최적화된 변환 메서드 사용
let result = try await model.transcribeOptimized(audioURL: audioURL)
```

## 다음 단계

- [모델 유형 및 특성](ModelTypes)
- [오류 처리 및 복구](ErrorHandling)
- [고급 사용 사례](AdvancedUsage)
- [API 참조](API) 