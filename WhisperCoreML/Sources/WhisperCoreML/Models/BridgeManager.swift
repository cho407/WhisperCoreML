import Foundation
import Combine
import CoreML

/// 브릿지 관리자 클래스 - 모든 브릿지 클래스를 통합 관리
public class BridgeManager {
    /// 싱글톤 인스턴스
    public static let shared = BridgeManager()
    
    /// 모델 타입 브릿지
    public let modelTypeBridge = ModelTypeBridge()
    
    /// 모델 브릿지
    public let modelBridge = ModelBridge()
    
    /// 파일 매니저
    private let fileManager = FileManager.default
    
    /// 기본 모델 디렉토리
    public let modelsDirectory: URL
    
    /// 공통 파일 디렉토리
    public let commonFilesDirectory: URL
    
    /// 초기화 메서드
    private init() {
        // 애플리케이션 지원 디렉토리
        let appSupportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.modelsDirectory = appSupportDirectory.appendingPathComponent("WhisperCoreML/Models", isDirectory: true)
        self.commonFilesDirectory = appSupportDirectory.appendingPathComponent("WhisperCoreML/Common", isDirectory: true)
        
        // 디렉토리 생성
        try? fileManager.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: commonFilesDirectory, withIntermediateDirectories: true)
    }
}

/// WhisperModelType 상태를 문자열로 다루는 브릿지 클래스
public class ModelTypeBridge {
    /// 모델 타입 문자열 목록
    public let allModelTypeStrings = [
        "tiny", "base", "small", "medium", "large", "large-v2", "large-v3", "large-v3-turbo"
    ]
    
    /// 모델의 허깅페이스 URL을 반환
    /// - Parameter modelType: 모델 타입 문자열
    /// - Returns: 모델 URL
    public func getHuggingFaceModelURL(for modelType: String) -> URL? {
        let baseURL = "https://huggingface.co/cho407/WhisperCoreML/resolve/main"
        let folder: String
        
        switch modelType {
        case "tiny": folder = "Tiny"
        case "base": folder = "Base"
        case "small": folder = "Small"
        case "medium": folder = "Medium"
        case "large": folder = "Large"
        case "large-v2": folder = "LargeV2" 
        case "large-v3": folder = "LargeV3"
        case "large-v3-turbo": folder = "LargeV3Turbo"
        default: return nil
        }
        
        return URL(string: "\(baseURL)/\(folder)")
    }
    
    /// 인코더 모델 이름을 반환
    /// - Parameter modelType: 모델 타입 문자열
    /// - Returns: 인코더 모델 이름
    public func getEncoderModelName(for modelType: String) -> String? {
        switch modelType {
        case "tiny": return "TinyEncoder"
        case "base": return "BaseEncoder"
        case "small": return "SmallEncoder"
        case "medium": return "MediumEncoder"
        case "large": return "LargeEncoder"
        case "large-v2": return "LargeV2Encoder"
        case "large-v3": return "LargeV3Encoder"
        case "large-v3-turbo": return "LargeV3TurboEncoder"
        default: return nil
        }
    }
    
    /// 디코더 모델 이름을 반환
    /// - Parameter modelType: 모델 타입 문자열
    /// - Returns: 디코더 모델 이름
    public func getDecoderModelName(for modelType: String) -> String? {
        switch modelType {
        case "tiny": return "TinyDecoder"
        case "base": return "BaseDecoder"
        case "small": return "SmallDecoder"
        case "medium": return "MediumDecoder"
        case "large": return "LargeDecoder"
        case "large-v2": return "LargeV2Decoder"
        case "large-v3": return "LargeV3Decoder"
        case "large-v3-turbo": return "LargeV3TurboDecoder"
        default: return nil
        }
    }
    
    /// 모델 타입에 해당하는 인코더 모델 URL 반환
    /// - Parameter modelType: 모델 타입 문자열
    /// - Returns: 인코더 모델 URL
    public func getEncoderModelURL(for modelType: String) -> URL? {
        guard let baseURL = getHuggingFaceModelURL(for: modelType),
              let encoderName = getEncoderModelName(for: modelType) else {
            return nil
        }
        return baseURL.appendingPathComponent("Whisper\(encoderName).mlpackage")
    }
    
    /// 모델 타입에 해당하는 디코더 모델 URL 반환
    /// - Parameter modelType: 모델 타입 문자열
    /// - Returns: 디코더 모델 URL
    public func getDecoderModelURL(for modelType: String) -> URL? {
        guard let baseURL = getHuggingFaceModelURL(for: modelType),
              let decoderName = getDecoderModelName(for: modelType) else {
            return nil
        }
        return baseURL.appendingPathComponent("Whisper\(decoderName).mlpackage")
    }
    
    /// 모델 타입에 해당하는 설정 파일 URL 반환
    /// - Parameter modelType: 모델 타입 문자열
    /// - Returns: 설정 파일 URL
    public func getConfigFileURL(for modelType: String) -> URL? {
        guard let baseURL = getHuggingFaceModelURL(for: modelType) else {
            return nil
        }
        return baseURL.appendingPathComponent("config.json")
    }
    
    /// 모델 타입에 해당하는 전처리 구성 파일 URL 반환
    /// - Parameter modelType: 모델 타입 문자열
    /// - Returns: 전처리 구성 파일 URL
    public func getPreprocessorConfigURL(for modelType: String) -> URL? {
        guard let baseURL = getHuggingFaceModelURL(for: modelType) else {
            return nil
        }
        return baseURL.appendingPathComponent("preprocessor_config.json")
    }
    
    /// 모델 타입에 해당하는 생성 구성 파일 URL 반환
    /// - Parameter modelType: 모델 타입 문자열
    /// - Returns: 생성 구성 파일 URL
    public func getGenerationConfigURL(for modelType: String) -> URL? {
        guard let baseURL = getHuggingFaceModelURL(for: modelType) else {
            return nil
        }
        return baseURL.appendingPathComponent("generation_config.json")
    }
    
    /// 모델 타입에 해당하는 로컬 모델 디렉토리 반환
    /// - Parameter modelType: 모델 타입 문자열
    /// - Returns: 로컬 모델 디렉토리
    public func getModelDirectory(for modelType: String) -> URL? {
        let bridgeManager = BridgeManager.shared
        let modelDirectory = bridgeManager.modelsDirectory.appendingPathComponent(modelType, isDirectory: true)
        
        // 디렉토리가 없으면 생성
        if !FileManager.default.fileExists(atPath: modelDirectory.path) {
            try? FileManager.default.createDirectory(at: modelDirectory, withIntermediateDirectories: true)
        }
        
        return modelDirectory
    }
    
    /// 모델 타입에 해당하는 로컬 인코더 모델 경로 반환
    /// - Parameter modelType: 모델 타입 문자열
    /// - Returns: 로컬 인코더 모델 경로
    public func getLocalEncoderModelPath(for modelType: String) -> URL? {
        guard let modelDirectory = getModelDirectory(for: modelType),
              let encoderName = getEncoderModelName(for: modelType) else {
            return nil
        }
        return modelDirectory.appendingPathComponent("Whisper\(encoderName).mlpackage")
    }
    
    /// 모델 타입에 해당하는 로컬 디코더 모델 경로 반환
    /// - Parameter modelType: 모델 타입 문자열
    /// - Returns: 로컬 디코더 모델 경로
    public func getLocalDecoderModelPath(for modelType: String) -> URL? {
        guard let modelDirectory = getModelDirectory(for: modelType),
              let decoderName = getDecoderModelName(for: modelType) else {
            return nil
        }
        return modelDirectory.appendingPathComponent("Whisper\(decoderName).mlpackage")
    }
    
    /// 모델 타입에 해당하는 로컬 설정 파일 경로 반환
    /// - Parameter modelType: 모델 타입 문자열
    /// - Returns: 로컬 설정 파일 경로
    public func getLocalConfigFilePath(for modelType: String) -> URL? {
        guard let modelDirectory = getModelDirectory(for: modelType) else {
            return nil
        }
        return modelDirectory.appendingPathComponent("config.json")
    }
    
    /// 모델의 인코더 파일이 로컬에 존재하는지 확인
    /// - Parameter modelType: 모델 타입 문자열
    /// - Returns: 존재 여부
    public func encoderModelExists(for modelType: String) -> Bool {
        guard let path = getLocalEncoderModelPath(for: modelType) else {
            return false
        }
        return FileManager.default.fileExists(atPath: path.path)
    }
    
    /// 모델의 디코더 파일이 로컬에 존재하는지 확인
    /// - Parameter modelType: 모델 타입 문자열
    /// - Returns: 존재 여부
    public func decoderModelExists(for modelType: String) -> Bool {
        guard let path = getLocalDecoderModelPath(for: modelType) else {
            return false
        }
        return FileManager.default.fileExists(atPath: path.path)
    }
    
    /// 모델의 설정 파일이 로컬에 존재하는지 확인
    /// - Parameter modelType: 모델 타입 문자열
    /// - Returns: 존재 여부
    public func configFileExists(for modelType: String) -> Bool {
        guard let path = getLocalConfigFilePath(for: modelType) else {
            return false
        }
        return FileManager.default.fileExists(atPath: path.path)
    }
    
    /// 모델의 모든 필수 파일이 존재하는지 확인
    /// - Parameter modelType: 모델 타입 문자열
    /// - Returns: 모든 필수 파일 존재 여부
    public func allRequiredFilesExist(for modelType: String) -> Bool {
        return encoderModelExists(for: modelType) &&
               decoderModelExists(for: modelType) &&
               configFileExists(for: modelType)
    }
    
    /// 공통 파일 디렉토리 URL
    public var commonFilesBaseURL: URL? {
        return URL(string: "https://huggingface.co/cho407/WhisperCoreML/resolve/main/Common")
    }
    
    /// 토크나이저 파일 URL
    public var tokenizerFileURL: URL? {
        return commonFilesBaseURL?.appendingPathComponent("tokenizer.json")
    }
    
    /// 어휘 파일 URL
    public var vocabFileURL: URL? {
        return commonFilesBaseURL?.appendingPathComponent("vocab.json")
    }
    
    /// 토크나이저 구성 파일 URL
    public var tokenizerConfigURL: URL? {
        return commonFilesBaseURL?.appendingPathComponent("tokenizer_config.json")
    }
    
    /// 특수 토큰 매핑 파일 URL
    public var specialTokensMapURL: URL? {
        return commonFilesBaseURL?.appendingPathComponent("special_tokens_map.json")
    }
    
    /// 병합 파일 URL
    public var mergesFileURL: URL? {
        return commonFilesBaseURL?.appendingPathComponent("merges.txt")
    }
    
    /// 정규화 파일 URL
    public var normalizerFileURL: URL? {
        return commonFilesBaseURL?.appendingPathComponent("normalizer.json")
    }
}

/// WhisperModel을 다루기 위한 브릿지 클래스
public class ModelBridge {
    /// 모델 오류
    public enum ModelError: Error, LocalizedError {
        /// 모델 초기화 실패
        case initializationFailed(String)
        
        /// 모델을 찾을 수 없음
        case modelNotFound(String)
        
        /// 모델 로딩 실패
        case loadingFailed(String)
        
        /// 오류 설명
        public var errorDescription: String? {
            switch self {
            case .initializationFailed(let message):
                return "모델 초기화 실패: \(message)"
            case .modelNotFound(let message):
                return "모델을 찾을 수 없음: \(message)"
            case .loadingFailed(let message):
                return "모델 로딩 실패: \(message)"
            }
        }
    }
    
    /// 모델 초기화
    /// - Parameter modelType: 모델 타입 문자열
    /// - Returns: 초기화된 모델 객체 (Any 타입)
    public func initializeModel(modelType: String) async throws -> Any {
        let bridgeManager = BridgeManager.shared
        let modelTypeBridge = bridgeManager.modelTypeBridge
        
        // 내장된 모델 (Tiny)
        if modelType == "tiny" {
            // 모델 경로를 검증하지만 변수 사용이 필요 없으므로 '_'로 대체
            _ = try getEmbeddedModelPath(for: modelType, isEncoder: true)
            _ = try getEmbeddedModelPath(for: modelType, isEncoder: false)
            
            let model = try await createWhisperModel(modelType: modelType)
            return model
        }
        
        // 다운로드된 모델
        if modelTypeBridge.allRequiredFilesExist(for: modelType) {
            let model = try await createWhisperModel(modelType: modelType)
            return model
        } else {
            throw ModelError.modelNotFound("모델 파일이 존재하지 않습니다. 먼저 모델을 다운로드하세요.")
        }
    }
    
    /// WhisperModel 생성
    /// - Parameter modelType: 모델 타입 문자열
    /// - Returns: 생성된 WhisperModel 인스턴스
    private func createWhisperModel(modelType: String) async throws -> WhisperModel {
        guard let modelType = WhisperModelType(rawValue: modelType) else {
            throw ModelError.initializationFailed("유효하지 않은 모델 타입: \(modelType)")
        }
        return try WhisperModel(modelType: modelType)
    }
    
    /// 내장된 모델 파일 경로 반환
    /// - Parameters:
    ///   - modelType: 모델 타입 문자열
    ///   - isEncoder: 인코더 여부
    /// - Returns: 모델 파일 경로
    private func getEmbeddedModelPath(for modelType: String, isEncoder: Bool) throws -> String {
        guard modelType == "tiny" else {
            throw ModelError.modelNotFound("내장된 모델은 Tiny 모델만 지원합니다.")
        }
        
        // 번들에서 모델 파일 찾기
        guard let bundle = Bundle(identifier: "com.whisper.WhisperCoreML") else {
            throw ModelError.modelNotFound("WhisperCoreML 번들을 찾을 수 없습니다.")
        }
        
        let fileName = isEncoder ? "WhisperTinyEncoder" : "WhisperTinyDecoder"
        guard let modelURL = bundle.url(forResource: fileName, withExtension: "mlpackage", subdirectory: "Resource/CoreMLModels/Tiny") else {
            throw ModelError.modelNotFound("\(fileName).mlpackage 파일을 찾을 수 없습니다.")
        }
        
        return modelURL.path
    }
}

/// 모델 래퍼 클래스 (실제 WhisperModel을 대체하는 임시 구현)
public class ModelWrapper {
    /// 모델 타입
    private let modelType: String
    
    /// 인코더 모델 경로
    private let encoderPath: String
    
    /// 디코더 모델 경로
    private let decoderPath: String
    
    /// 통합 모델 (WhisperModel)
    public var model: WhisperModel?
    
    /// 초기화
    /// - Parameters:
    ///   - modelType: 모델 타입
    ///   - encoderPath: 인코더 모델 경로
    ///   - decoderPath: 디코더 모델 경로
    public init(modelType: String, encoderPath: String, decoderPath: String) {
        self.modelType = modelType
        self.encoderPath = encoderPath
        self.decoderPath = decoderPath
    }
    
    /// 모델 로드
    public func loadModel() async throws {
        // 모델 파일 존재 확인
        guard FileManager.default.fileExists(atPath: encoderPath) else {
            throw ModelBridge.ModelError.modelNotFound("인코더 모델 파일을 찾을 수 없습니다: \(encoderPath)")
        }
        
        guard FileManager.default.fileExists(atPath: decoderPath) else {
            throw ModelBridge.ModelError.modelNotFound("디코더 모델 파일을 찾을 수 없습니다: \(decoderPath)")
        }
        
        // WhisperModel 생성
        guard let modelType = WhisperModelType(rawValue: self.modelType) else {
            throw ModelBridge.ModelError.initializationFailed("유효하지 않은 모델 타입: \(self.modelType)")
        }
        
        self.model = try WhisperModel(modelType: modelType)
    }
} 