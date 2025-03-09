# API 참조

WhisperCoreML 라이브러리의 주요 클래스와 메서드에 대한 참조 문서입니다.

## WhisperModel

음성 인식 및 번역을 위한 핵심 클래스입니다.

### 초기화

```swift
// 모델 타입으로 초기화
public init(modelType: WhisperModelType) throws

// 모델 경로로 초기화
public init(modelPath: String) throws
```

### 모델 관리

```swift
// 모델 로드
public func loadModel() async throws

// 모델 다운로드
public func downloadModel(progressHandler: @escaping (Double) -> Void) -> AnyPublisher<Void, WhisperError>

// 모델 삭제
public func deleteModel() throws

// 모델 정보 가져오기
public func getModelInfo() -> [String: Any]

// 성능 최적화 제안 가져오기
public func getOptimizationSuggestions() async -> [String]
```

### 음성 인식

```swift
// 오디오 파일 변환
public func transcribe(
    audioURL: URL,
    options: TranscriptionOptions = .default,
    progressHandler: @escaping (Double) -> Void = { _ in }
) async throws -> TranscriptionResult

// 최적화된 오디오 파일 변환
public func transcribeOptimized(
    audioURL: URL,
    options: TranscriptionOptions = .default,
    progressHandler: @escaping (Double) -> Void
) async throws -> TranscriptionResult
```

### 번역

```swift
// 오디오 파일 번역
public func translateAudio(
    _ audioURL: URL,
    options: TranslationOptions = .default,
    progressHandler: @escaping (Double) -> Void
) async throws -> TranslationResult
```

## WhisperModelType

지원하는 모델 타입을 정의하는 열거형입니다.

```swift
public enum WhisperModelType: String, CaseIterable {
    case tiny
    case base
    case small
    case medium
    case large
    case largeV2
    case largeV3
    
    // 모델 표시 이름
    public var displayName: String
    
    // 모델 크기 (MB)
    public var sizeInMB: Int
    
    // 다운로드 URL
    public var downloadURL: URL?
    
    // 로컬 모델 경로
    public func localModelPath() -> URL
    
    // 모델 존재 여부 확인
    public func modelExists() -> Bool
    
    // 모델 파일 크기 가져오기
    public func modelFileSize() -> Int64?
}
```

## TranscriptionOptions

음성 인식 옵션을 정의하는 구조체입니다.

```swift
public struct TranscriptionOptions: Codable, Equatable {
    // 언어 코드 (nil로 설정하면 자동 감지)
    public let language: String?
    
    // 변환 작업 (transcribe 또는 translate)
    public let task: TranscriptionTask
    
    // 샘플링 온도 (0.0 ~ 1.0)
    public let temperature: Float
    
    // 압축 비율
    public let compressionRatio: Float
    
    // 로그 확률 임계값
    public let logProbThreshold: Float
    
    // 무음 임계값
    public let silenceThreshold: Float
    
    // 초기 프롬프트
    public let initialPrompt: String?
    
    // 단어 수준 타임스탬프 활성화 여부
    public let enableWordTimestamps: Bool
    
    // 번역 품질 (0.0 ~ 1.0)
    public let translationQuality: Float?
    
    // 보존할 형식
    public let preserveFormats: Set<PreserveFormat>
    
    // 기본 옵션
    public static let `default` = TranscriptionOptions(
        language: nil,
        task: .transcribe
    )
    
    // 초기화
    public init(
        language: String? = nil,
        task: TranscriptionTask = .transcribe,
        temperature: Float = 0.0,
        compressionRatio: Float = 2.4,
        logProbThreshold: Float = -1.0,
        silenceThreshold: Float = 0.6,
        initialPrompt: String? = nil,
        enableWordTimestamps: Bool = false,
        translationQuality: Float? = nil,
        preserveFormats: Set<PreserveFormat> = []
    )
    
    // 사전 표현으로 변환
    public func toDictionary() -> [String: Any]
}
```

## TranscriptionTask

변환 작업 유형을 정의하는 열거형입니다.

```swift
public enum TranscriptionTask: Codable, Equatable {
    case transcribe
    case translate
    case translateTo(String)
}
```

## PreserveFormat

보존할 형식을 정의하는 열거형입니다.

```swift
public enum PreserveFormat: String, Codable, Hashable {
    case numbers
    case names
    case dates
    case urls
    case emails
    case phoneNumbers
    case addresses
}
```

## TranscriptionResult

음성 인식 결과를 나타내는 구조체입니다.

```swift
public struct TranscriptionResult: Codable, Equatable {
    // 변환된 텍스트 세그먼트 배열
    public let segments: [TranscriptionSegment]
    
    // 감지된 언어 (ISO 코드)
    public let detectedLanguage: String?
    
    // 변환에 사용된 옵션
    public let options: TranscriptionOptions
    
    // 변환에 걸린 시간 (초)
    public let processingTime: TimeInterval
    
    // 오디오 길이 (초)
    public let audioDuration: TimeInterval
    
    // 전체 텍스트 (모든 세그먼트 결합)
    public var text: String
    
    // 사전 표현으로 변환
    public func toDictionary() -> [String: Any]
    
    // JSON 데이터로 변환
    public func toJSONData() throws -> Data
    
    // JSON 문자열로 변환
    public func toJSONString() throws -> String
}
```

## TranscriptionSegment

음성 인식 세그먼트를 나타내는 구조체입니다.

```swift
public struct TranscriptionSegment: Identifiable, Codable, Equatable {
    // 고유 식별자
    public let id: UUID
    
    // 세그먼트 인덱스
    public let index: Int
    
    // 변환된 텍스트
    public let text: String
    
    // 시작 시간 (초)
    public let start: TimeInterval
    
    // 종료 시간 (초)
    public let end: TimeInterval
    
    // 신뢰도 점수 (0.0 ~ 1.0)
    public let confidence: Float?
    
    // 단어 수준 타임스탬프 (활성화된 경우)
    public let words: [WordTimestamp]?
    
    // 세그먼트 길이 (초)
    public var duration: TimeInterval
}
```

## WordTimestamp

단어 수준 타임스탬프를 나타내는 구조체입니다.

```swift
public struct WordTimestamp: Identifiable, Codable, Equatable {
    // 고유 식별자
    public let id: UUID
    
    // 단어 텍스트
    public let word: String
    
    // 시작 시간 (초)
    public let start: TimeInterval
    
    // 종료 시간 (초)
    public let end: TimeInterval
    
    // 신뢰도 점수 (0.0 ~ 1.0)
    public let confidence: Float?
}
```

## TranslationOptions

번역 옵션을 정의하는 구조체입니다.

```swift
public struct TranslationOptions {
    // 대상 언어 (ISO 639-1 코드)
    public let targetLanguage: String
    
    // 번역 품질 (0.0 ~ 1.0, 높을수록 더 높은 품질)
    public let quality: Float
    
    // 보존할 형식
    public let preserveFormats: Set<PreserveFormat>
    
    // 기본 옵션 (영어로 번역)
    public static let `default` = TranslationOptions(
        targetLanguage: "en",
        quality: 0.7,
        preserveFormats: [.numbers, .names]
    )
}
```

## TranslationResult

번역 결과를 나타내는 구조체입니다.

```swift
public struct TranslationResult {
    // 원본 텍스트
    public let originalText: String
    
    // 번역된 텍스트
    public let translatedText: String
    
    // 원본 언어
    public let sourceLanguage: String
    
    // 대상 언어
    public let targetLanguage: String
    
    // 번역 신뢰도 (0.0 ~ 1.0)
    public let confidence: Double
    
    // 번역 시간 (초)
    public let processingTime: TimeInterval
}
```

## BatchProcessor

여러 오디오 파일을 배치로 처리하는 클래스입니다.

```swift
public actor BatchProcessor {
    // 초기화
    public init(model: WhisperModel, maxConcurrentProcessing: Int = 2)
    
    // 배치 처리
    public func processBatch(
        urls: [URL],
        progressHandler: @escaping @MainActor (BatchProcessingStatus) -> Void
    ) async throws -> [BatchProcessingResult]
    
    // 처리 취소
    public func cancelProcessing() async
    
    // 처리 통계 초기화
    public func resetStatistics() async
}
```

## BatchProcessingStatus

배치 처리 상태를 나타내는 구조체입니다.

```swift
public struct BatchProcessingStatus {
    // 전체 파일 수
    public let totalFiles: Int
    
    // 처리된 파일 수
    public let processedFiles: Int
    
    // 현재 처리 중인 파일
    public let currentFile: String
    
    // 전체 진행률 (0.0 ~ 1.0)
    public let progress: Double
    
    // 남은 예상 시간 (초)
    public let estimatedTimeRemaining: TimeInterval?
    
    // 처리 속도 (초당 처리된 파일 수)
    public let processingSpeed: Double?
    
    // 현재 파일의 처리 진행률 (0.0 ~ 1.0)
    public let currentFileProgress: Double?
    
    // 처리 중 발생한 오류 수
    public let errorCount: Int
}
```

## BatchProcessingResult

배치 처리 결과를 나타내는 구조체입니다.

```swift
public struct BatchProcessingResult {
    // 파일 URL
    public let fileURL: URL
    
    // 변환 결과
    public let transcription: String
    
    // 감지된 언어
    public let language: String?
    
    // 오디오 길이 (초)
    public let duration: TimeInterval
    
    // 오류
    public let error: Error?
    
    // 처리 시간 (초)
    public let processingTime: TimeInterval
    
    // 파일 크기 (바이트)
    public let fileSize: Int64
}
```

## AudioProcessor

오디오 처리를 위한 클래스입니다.

```swift
public class AudioProcessor {
    // 오디오 파일 로드
    public func loadAudioFile(url: URL) async throws -> AudioData
    
    // 멜 스펙트로그램 추출
    public func extractMelSpectrogram(from audioData: AudioData) throws -> [Float]
    
    // 오디오 형식 변환
    public func convertAudioFormat(
        from sourceURL: URL,
        to destinationURL: URL,
        format: AudioFormat = .wav
    ) async throws
}
```

## AudioData

오디오 데이터를 나타내는 구조체입니다.

```swift
public struct AudioData {
    // 오디오 샘플
    public let samples: [Float]
    
    // 샘플 레이트
    public let sampleRate: Int
    
    // 오디오 길이 (초)
    public var duration: TimeInterval
    
    // 오디오 데이터 슬라이스
    public func slice(from startTime: TimeInterval, to endTime: TimeInterval) -> AudioData
}
```

## AudioFormat

오디오 형식을 정의하는 열거형입니다.

```swift
public enum AudioFormat: String {
    case wav
    case mp3
    case aac
    case flac
    case m4a
    case ogg
}
```

## WhisperError

Whisper 관련 오류를 정의하는 열거형입니다.

```swift
public enum WhisperError: LocalizedError {
    // 모델 관련 오류
    case modelNotFound
    case modelLoadFailed(String)
    case modelLoadingFailed(Error)
    case modelNotLoaded
    case invalidModelURL
    case modelInputPreparationFailed(String)
    case modelOutputProcessingFailed(String)
    case modelUnavailableOffline(requestedModel: WhisperModelType, availableAlternative: WhisperModelType?)
    case noModelsAvailableOffline
    case modelVersionMismatch(expected: String, found: String)
    case modelCorrupted(reason: String)
    
    // 오디오 처리 관련 오류
    case audioProcessingFailed(String)
    case invalidAudioFormat(String)
    case audioStreamError(String)
    case audioEngineError(String)
    
    // 네트워크 관련 오류
    case networkError(String)
    case downloadFailed(String)
    case networkUnavailable
    case connectionTimeout(TimeInterval)
    case serverError(Int)
    
    // 파일 시스템 관련 오류
    case fileSystemError(String)
    case fileNotFound(String)
    case invalidFilePath(String)
    case insufficientDiskSpace
    case diskWriteError(path: String)
    case diskReadError(path: String)
    
    // 토크나이저 관련 오류
    case tokenizerError(String)
    case invalidTokenSequence(String)
    
    // 배치 처리 관련 오류
    case batchProcessingError(String)
    case concurrencyError(String)
    
    // 일반 오류
    case invalidConfiguration(String)
    case internalError(String)
    case unknown(String)
    
    // 오류 설명
    public var errorDescription: String?
    
    // 복구 제안
    public var recoverySuggestion: String?
    
    // 실패 이유
    public var failureReason: String?
    
    // 오류 복구 옵션
    public var recoveryOptions: ErrorRecoveryOptions
}
```

## ErrorRecoveryOptions

오류 복구 옵션을 나타내는 구조체입니다.

```swift
public struct ErrorRecoveryOptions {
    // 재시도 가능 여부
    public let canRetry: Bool
    
    // 제안된 복구 작업
    public let suggestedAction: RecoveryAction?
    
    // 사용자 메시지
    public let message: String
    
    // 복구 작업 유형
    public enum RecoveryAction {
        case retryDownload
        case useAlternativeModel(WhisperModelType)
        case clearCache
        case checkNetworkConnection
        case freeDiskSpace
    }
}
```

## ErrorRecoveryHelper

오류 복구를 돕는 구조체입니다.

```swift
public struct ErrorRecoveryHelper {
    // 오류 복구 시도
    public static func attemptRecovery(from error: WhisperError) async -> Bool
}
```

## ErrorLogger

오류 로깅을 위한 구조체입니다.

```swift
public struct ErrorLogger {
    // 로그 레벨
    public enum LogLevel: Int, Comparable {
        case debug = 0
        case info = 1
        case warning = 2
        case error = 3
        case critical = 4
    }
    
    // 로그 레벨 설정
    public static func setLogLevel(_ level: LogLevel)
    
    // 오류 로그 기록
    public static func log(
        _ error: WhisperError,
        level: LogLevel = .error,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    )
    
    // 일반 메시지 로깅
    public static func log(
        _ message: String,
        level: LogLevel = .info,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    )
}
```

## NetworkMonitor

네트워크 상태를 모니터링하는 클래스입니다.

```swift
public class NetworkMonitor {
    // 네트워크 유형
    public enum NetworkType {
        case wifi
        case cellular
        case ethernet
        case unknown
    }
    
    // 현재 네트워크 유형
    public static var currentNetworkType: NetworkType
    
    // 네트워크 상태 변경 콜백
    public static var onNetworkStatusChanged: ((Bool, NetworkType) -> Void)?
    
    // 네트워크 모니터 시작
    public static func startMonitorIfNeeded()
    
    // 네트워크 모니터 중지
    public static func stopMonitor()
    
    // 네트워크 사용 가능 여부 확인
    public static func isNetworkAvailable() -> Bool
    
    // 현재 네트워크 상태 확인
    public static func checkCurrentStatus() -> (isConnected: Bool, type: NetworkType)
}
```

## MemoryManager

메모리 사용량을 관리하는 클래스입니다.

```swift
public class MemoryManager {
    // 싱글톤 인스턴스
    public static let shared = MemoryManager()
    
    // 메모리 정보
    public struct MemoryInfo {
        public let usedMemory: Double
        public let availableMemory: Double
        public let totalMemory: Double
    }
    
    // 메모리 경고 콜백
    public var onMemoryWarning: ((Double) -> Void)?
    
    // 메모리 사용량 임계값 설정
    public func setMemoryWarningThreshold(_ threshold: Double)
    
    // 메모리 정보 가져오기
    public func getMemoryInfo() -> MemoryInfo
    
    // 메모리 사용량 확인
    public func checkMemoryUsage() -> Double
    
    // 메모리 확보
    public func freeMemory() -> Bool
}
```

## ModelMetadataManager

모델 메타데이터를 관리하는 클래스입니다.

```swift
public class ModelMetadataManager {
    // 싱글톤 인스턴스
    public static let shared = ModelMetadataManager()
    
    // 모델 메타데이터 가져오기
    public func getMetadata(for modelType: WhisperModelType) -> ModelMetadata?
    
    // 모델 메타데이터 설정
    public func setMetadata(_ metadata: ModelMetadata, for modelType: WhisperModelType)
    
    // 모델 사용 기록
    public func recordModelUsage(modelType: WhisperModelType, processingTime: TimeInterval)
    
    // 모든 모델 메타데이터 가져오기
    public func getAllMetadata() -> [ModelMetadata]
    
    // 모델 메타데이터 삭제
    public func removeMetadata(for modelType: WhisperModelType)
    
    // 기본 메타데이터 생성
    public func createDefaultMetadata(for modelType: WhisperModelType) -> ModelMetadata
}
```

## ModelMetadata

모델 메타데이터를 나타내는 구조체입니다.

```swift
public struct ModelMetadata: Codable, Equatable {
    // 모델 타입
    public let modelType: WhisperModelType
    
    // 모델 버전
    public let version: String
    
    // 릴리스 날짜
    public let releaseDate: Date
    
    // 마지막 사용 날짜
    public var lastUsedDate: Date
    
    // 사용 횟수
    public var usageCount: Int
    
    // 평균 처리 시간 (초)
    public var averageProcessingTime: TimeInterval
    
    // 모델 파일 크기 (바이트)
    public let fileSize: Int64
    
    // 지원하는 언어 목록
    public let supportedLanguages: [String]
    
    // 모델 성능 지표
    public let performanceMetrics: PerformanceMetrics
    
    // 모델 파일 경로
    public let filePath: String
    
    // 모델 다운로드 URL
    public let downloadURL: URL?
    
    // 모델 체크섬 (SHA-256)
    public let checksum: String?
    
    // 추가 정보
    public var additionalInfo: [String: String]
    
    // 모델 사용 기록 업데이트
    public mutating func recordUsage(processingTime: TimeInterval)
    
    // 사전 표현으로 변환
    public func toDictionary() -> [String: Any]
    
    // 사전에서 생성
    public static func fromDictionary(_ dict: [String: Any]) -> ModelMetadata?
}
```

## PerformanceMetrics

성능 지표를 나타내는 구조체입니다.

```swift
public struct PerformanceMetrics: Codable, Equatable {
    // 정확도 (0.0 ~ 1.0)
    public let accuracy: Float
    
    // 평균 처리 속도 (초당 오디오 길이)
    public let processingSpeed: Float
    
    // 메모리 사용량 (MB)
    public let memoryUsage: Float
    
    // 사전 표현으로 변환
    public func toDictionary() -> [String: Any]
    
    // 사전에서 생성
    public static func fromDictionary(_ dict: [String: Any]) -> PerformanceMetrics?
}
```

## PerformanceOptimizer

성능 최적화를 위한 클래스입니다.

```swift
public class PerformanceOptimizer {
    // 설정
    public struct Configuration {
        public let enableNeuralEngine: Bool
        public let enableGPU: Bool
        public let enableLowPrecision: Bool
        
        public static let `default` = Configuration(
            enableNeuralEngine: true,
            enableGPU: true,
            enableLowPrecision: true
        )
    }
    
    // 초기화
    public init(configuration: Configuration)
    
    // 권장 컴퓨팅 유닛 가져오기
    public func recommendedComputeUnits() async -> MLComputeUnits
    
    // 최적화 제안 가져오기
    public func getOptimizationSuggestions() async -> [String]
} 