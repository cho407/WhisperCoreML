import Foundation

/// 음성 변환 작업 유형
public enum TranscriptionTask: Codable, Sendable {
    /// 음성을 텍스트로 변환 (원본 언어 유지)
    case transcribe
    
    /// 음성을 영어 텍스트로 번역
    case translate
    
    /// 음성을 특정 언어로 번역
    case translateTo(String)
    
    // Codable 지원을 위한 코딩 키
    private enum CodingKeys: String, CodingKey {
        case type, targetLanguage
    }
    
    // 인코딩 구현
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .transcribe:
            try container.encode("transcribe", forKey: .type)
        case .translate:
            try container.encode("translate", forKey: .type)
        case .translateTo(let language):
            try container.encode("translateTo", forKey: .type)
            try container.encode(language, forKey: .targetLanguage)
        }
    }
    
    // 디코딩 구현
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "transcribe":
            self = .transcribe
        case "translate":
            self = .translate
        case "translateTo":
            let language = try container.decode(String.self, forKey: .targetLanguage)
            self = .translateTo(language)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown task type: \(type)"
            )
        }
    }
}

/// 음성 변환 옵션
public struct TranscriptionOptions: Codable, Equatable, Sendable {
    /// 변환할 언어 (nil인 경우 자동 감지)
    public var language: String?
    
    /// 변환 작업 유형 (transcribe 또는 translate)
    public var task: TranscriptionTask
    
    /// 샘플링 온도 (높을수록 다양한 결과, 낮을수록 일관된 결과)
    public var temperature: Float
    
    /// 압축 비율 (높을수록 더 짧은 세그먼트)
    public var compressionRatio: Float
    
    /// 로그 확률 임계값 (낮을수록 더 많은 텍스트 생성)
    public var logProbThreshold: Float
    
    /// 무음 임계값 (초 단위, 이 시간 이상의 무음은 새 세그먼트로 간주)
    public var silenceThreshold: Float
    
    /// 초기 프롬프트 (변환 시작 시 사용할 텍스트)
    public var initialPrompt: String?
    
    /// 단어 타임스탬프 활성화 여부
    public var enableWordTimestamps: Bool
    
    /// 번역 품질 (0.0 ~ 1.0, 높을수록 더 높은 품질)
    public var translationQuality: Float
    
    /// 번역 보존 포맷 (번역 시 보존할 형식)
    public var preserveFormats: Set<PreserveFormat>
    
    /// 기본 옵션
    public static var `default`: TranscriptionOptions {
        TranscriptionOptions(
            language: nil,
            task: .transcribe,
            temperature: 0.0,
            compressionRatio: 2.4,
            logProbThreshold: -1.0,
            silenceThreshold: 0.6,
            initialPrompt: nil,
            enableWordTimestamps: false,
            translationQuality: 0.7,
            preserveFormats: [.numbers, .names]
        )
    }
    
    /// 초기화 메서드
    public init(
        language: String? = nil,
        task: TranscriptionTask = .transcribe,
        temperature: Float = 0.0,
        compressionRatio: Float = 2.4,
        logProbThreshold: Float = -1.0,
        silenceThreshold: Float = 0.6,
        initialPrompt: String? = nil,
        enableWordTimestamps: Bool = false,
        translationQuality: Float = 0.7,
        preserveFormats: Set<PreserveFormat> = [.numbers, .names]
    ) {
        self.language = language
        self.task = task
        self.temperature = temperature
        self.compressionRatio = compressionRatio
        self.logProbThreshold = logProbThreshold
        self.silenceThreshold = silenceThreshold
        self.initialPrompt = initialPrompt
        self.enableWordTimestamps = enableWordTimestamps
        self.translationQuality = translationQuality
        self.preserveFormats = preserveFormats
    }
    
    /// 사전 표현으로 변환
    public func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "temperature": temperature,
            "compression_ratio": compressionRatio,
            "log_prob_threshold": logProbThreshold,
            "silence_threshold": silenceThreshold,
            "enable_word_timestamps": enableWordTimestamps,
            "translation_quality": translationQuality,
            "preserve_formats": preserveFormats.map { $0.rawValue }
        ]
        
        // 작업 유형 설정
        switch task {
        case .transcribe:
            dict["task"] = "transcribe"
        case .translate:
            dict["task"] = "translate"
        case .translateTo(let targetLanguage):
            dict["task"] = "translateTo"
            dict["target_language"] = targetLanguage
        }
        
        if let language = language {
            dict["language"] = language
        }
        
        if let initialPrompt = initialPrompt {
            dict["initial_prompt"] = initialPrompt
        }
        
        return dict
    }
    
    /// 사전에서 옵션 생성
    public static func fromDictionary(_ dict: [String: Any]) -> TranscriptionOptions {
        let language = dict["language"] as? String
        let taskString = dict["task"] as? String ?? "transcribe"
        
        // 작업 유형 파싱
        let task: TranscriptionTask
        if taskString == "transcribe" {
            task = .transcribe
        } else if taskString == "translate" {
            task = .translate
        } else if taskString == "translateTo", let targetLanguage = dict["target_language"] as? String {
            task = .translateTo(targetLanguage)
        } else {
            task = .transcribe
        }
        
        let temperature = dict["temperature"] as? Float ?? 0.0
        let compressionRatio = dict["compression_ratio"] as? Float ?? 2.4
        let logProbThreshold = dict["log_prob_threshold"] as? Float ?? -1.0
        let silenceThreshold = dict["silence_threshold"] as? Float ?? 0.6
        let initialPrompt = dict["initial_prompt"] as? String
        let enableWordTimestamps = dict["enable_word_timestamps"] as? Bool ?? false
        let translationQuality = dict["translation_quality"] as? Float ?? 0.7
        
        // 보존 형식 파싱
        let preserveFormatStrings = dict["preserve_formats"] as? [String] ?? []
        let preserveFormats = Set(preserveFormatStrings.compactMap { PreserveFormat(rawValue: $0) })
        
        return TranscriptionOptions(
            language: language,
            task: task,
            temperature: temperature,
            compressionRatio: compressionRatio,
            logProbThreshold: logProbThreshold,
            silenceThreshold: silenceThreshold,
            initialPrompt: initialPrompt,
            enableWordTimestamps: enableWordTimestamps,
            translationQuality: translationQuality,
            preserveFormats: preserveFormats
        )
    }
    
    /// Equatable 구현
    public static func == (lhs: TranscriptionOptions, rhs: TranscriptionOptions) -> Bool {
        lhs.language == rhs.language &&
        lhs.temperature == rhs.temperature &&
        lhs.compressionRatio == rhs.compressionRatio &&
        lhs.logProbThreshold == rhs.logProbThreshold &&
        lhs.silenceThreshold == rhs.silenceThreshold &&
        lhs.initialPrompt == rhs.initialPrompt &&
        lhs.enableWordTimestamps == rhs.enableWordTimestamps &&
        lhs.translationQuality == rhs.translationQuality &&
        lhs.preserveFormats == rhs.preserveFormats &&
        {
            switch (lhs.task, rhs.task) {
            case (.transcribe, .transcribe), (.translate, .translate):
                return true
            case (.translateTo(let lhsLang), .translateTo(let rhsLang)):
                return lhsLang == rhsLang
            default:
                return false
            }
        }()
    }
}

/// 번역 시 보존할 형식
public enum PreserveFormat: String, Codable, Sendable {
    /// 숫자 형식 보존
    case numbers
    
    /// 이름 보존
    case names
    
    /// 날짜 형식 보존
    case dates
    
    /// 시간 형식 보존
    case times
    
    /// 이메일 주소 보존
    case emails
    
    /// URL 보존
    case urls
    
    /// 특수 문자 보존
    case specialCharacters
} 
