import Foundation

/// Whisper 모델 타입을 정의하는 열거형
public enum WhisperModelType: String, CaseIterable, Identifiable, Sendable {
    /// 75MB 크기의 Tiny 모델
    case tiny = "tiny"
    
    /// 142MB 크기의 Base 모델
    case base = "base"
    
    /// 466MB 크기의 Small 모델
    case small = "small"
    
    /// 1.5GB 크기의 Medium 모델
    case medium = "medium"
    
    /// 3GB 크기의 Large-v3 모델
    case largeV3 = "large-v3"
    
    /// 3GB 크기의 Large-v3 turbo 모델
    case largeV3Turbo = "large-v3-turbo"
    
    /// 고유 식별자
    public var id: String { rawValue }
    
    /// 모델 표시 이름
    public var displayName: String {
        switch self {
        case .tiny: return "Tiny"
        case .base: return "Base"
        case .small: return "Small"
        case .medium: return "Medium"
        case .largeV3: return "Large-v3"
        case .largeV3Turbo: return "Large-v3-Turbo"
        }
    }
    
    /// 모델 크기 (MB 단위)
    public var sizeInMB: Int {
        switch self {
        case .tiny: return 75
        case .base: return 142
        case .small: return 466
        case .medium: return 1500
        case .largeV3: return 3000
        case .largeV3Turbo: return 3000
        }
    }
    
    /// 모델 다운로드 URL (Hugging Face)
    public var huggingFaceModelURL: URL {
        let baseURL = "https://huggingface.co/cho407/WhisperCoreML/resolve/main"
        let folder: String
        
        switch self {
        case .tiny: folder = "Tiny"
        case .base: folder = "Base"
        case .small: folder = "Small"
        case .medium: folder = "Medium"
        case .largeV3: folder = "Large-V3"
        case .largeV3Turbo: folder = "Large-V3-turbo"
        }
        
        return URL(string: "\(baseURL)/\(folder)")!
    }
    
    /// 인코더 모델 다운로드 URL
    public var encoderModelURL: URL {
        huggingFaceModelURL.appendingPathComponent("Whisper\(encoderModelName).mlpackage")
    }
    
    /// 디코더 모델 다운로드 URL
    public var decoderModelURL: URL {
        huggingFaceModelURL.appendingPathComponent("Whisper\(decoderModelName).mlpackage")
    }
    
    /// 모델 구성 파일 다운로드 URL
    public var configFileURL: URL {
        huggingFaceModelURL.appendingPathComponent("config.json")
    }
    
    /// 사전 처리 구성 파일 다운로드 URL
    public var preprocessorConfigURL: URL {
        huggingFaceModelURL.appendingPathComponent("preprocessor_config.json")
    }
    
    /// 생성 구성 파일 다운로드 URL
    public var generationConfigURL: URL {
        huggingFaceModelURL.appendingPathComponent("generation_config.json")
    }
    
    /// 인코더 모델 이름
    public var encoderModelName: String {
        switch self {
        case .tiny: return "TinyEncoder"
        case .base: return "BaseEncoder"
        case .small: return "SmallEncoder"
        case .medium: return "MediumEncoder"
        case .largeV3: return "LargeV3Encoder"
        case .largeV3Turbo: return "LargeV3TurboEncoder"
        }
    }
    
    /// 디코더 모델 이름
    public var decoderModelName: String {
        switch self {
        case .tiny: return "TinyDecoder"
        case .base: return "BaseDecoder"
        case .small: return "SmallDecoder"
        case .medium: return "MediumDecoder"
        case .largeV3: return "LargeV3Decoder"
        case .largeV3Turbo: return "LargeV3TurboDecoder"
        }
    }
    
    /// 공통 파일 다운로드 URL
    public static var commonFilesBaseURL: URL {
        URL(string: "https://huggingface.co/cho407/WhisperCoreML/resolve/main/Common")!
    }
    
    /// 토크나이저 파일 URL
    public static var tokenizerFileURL: URL {
        commonFilesBaseURL.appendingPathComponent("tokenizer.json")
    }
    
    /// 어휘 파일 URL
    public static var vocabFileURL: URL {
        commonFilesBaseURL.appendingPathComponent("vocab.json")
    }
    
    /// 토크나이저 구성 파일 URL
    public static var tokenizerConfigURL: URL {
        commonFilesBaseURL.appendingPathComponent("tokenizer_config.json")
    }
    
    /// 특수 토큰 매핑 파일 URL
    public static var specialTokensMapURL: URL {
        commonFilesBaseURL.appendingPathComponent("special_tokens_map.json")
    }
    
    /// 병합 파일 URL (BPE)
    public static var mergesFileURL: URL {
        commonFilesBaseURL.appendingPathComponent("merges.txt")
    }
    
    /// 정규화 파일 URL
    public static var normalizerFileURL: URL {
        commonFilesBaseURL.appendingPathComponent("normalizer.json")
    }
    
    /// 인코더 모델 로컬 경로
    public func localEncoderModelPath() -> URL {
        let fileManager = FileManager.default
        let appSupportURL = try! fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let modelDirectory = appSupportURL.appendingPathComponent("WhisperCoreML/Models/\(rawValue)", isDirectory: true)
        
        // 디렉토리가 없으면 생성
        if !fileManager.fileExists(atPath: modelDirectory.path) {
            try? fileManager.createDirectory(at: modelDirectory, withIntermediateDirectories: true)
        }
        
        return modelDirectory.appendingPathComponent("Whisper\(encoderModelName).mlpackage")
    }
    
    /// 디코더 모델 로컬 경로
    public func localDecoderModelPath() -> URL {
        let fileManager = FileManager.default
        let appSupportURL = try! fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let modelDirectory = appSupportURL.appendingPathComponent("WhisperCoreML/Models/\(rawValue)", isDirectory: true)
        
        // 디렉토리가 없으면 생성
        if !fileManager.fileExists(atPath: modelDirectory.path) {
            try? fileManager.createDirectory(at: modelDirectory, withIntermediateDirectories: true)
        }
        
        return modelDirectory.appendingPathComponent("Whisper\(decoderModelName).mlpackage")
    }
    
    /// 모델 구성 파일 로컬 경로
    public func localConfigFilePath() -> URL {
        let fileManager = FileManager.default
        let appSupportURL = try! fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let modelDirectory = appSupportURL.appendingPathComponent("WhisperCoreML/Models/\(rawValue)", isDirectory: true)
        
        // 디렉토리가 없으면 생성
        if !fileManager.fileExists(atPath: modelDirectory.path) {
            try? fileManager.createDirectory(at: modelDirectory, withIntermediateDirectories: true)
        }
        
        return modelDirectory.appendingPathComponent("config.json")
    }
    
    /// 인코더 모델이 로컬에 존재하는지 확인
    public func encoderModelExists() -> Bool {
        FileManager.default.fileExists(atPath: localEncoderModelPath().path)
    }
    
    /// 디코더 모델이 로컬에 존재하는지 확인
    public func decoderModelExists() -> Bool {
        FileManager.default.fileExists(atPath: localDecoderModelPath().path)
    }
    
    /// 모델 구성 파일이 로컬에 존재하는지 확인
    public func configFileExists() -> Bool {
        FileManager.default.fileExists(atPath: localConfigFilePath().path)
    }
    
    /// 모델의 모든 필수 파일이 로컬에 존재하는지 확인
    public func allRequiredFilesExist() -> Bool {
        encoderModelExists() && decoderModelExists() && configFileExists()
    }
    
    /// 모델 파일 크기 (바이트)
    public var modelFileSize: Int64 {
        switch self {
        case .tiny: return 75_000_000
        case .base: return 142_000_000
        case .small: return 466_000_000
        case .medium: return 1_500_000_000
        case .largeV3: return 3_000_000_000
        case .largeV3Turbo: return 3_000_000_000
        }
    }
    
    /// 모델 파일 존재 여부 확인
    public func modelExists(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }
} 
