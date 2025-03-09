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
    
    /// 3GB 크기의 Large 모델
    case large = "large"
    
    /// 3GB 크기의 Large-v2 모델
    case largeV2 = "large-v2"
    
    /// 3GB 크기의 Large-v3 모델
    case largeV3 = "large-v3"
    
    /// 고유 식별자
    public var id: String { rawValue }
    
    /// 모델 표시 이름
    public var displayName: String {
        switch self {
        case .tiny: return "Tiny"
        case .base: return "Base"
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        case .largeV2: return "Large-v2"
        case .largeV3: return "Large-v3"
        }
    }
    
    /// 모델 크기 (MB 단위)
    public var sizeInMB: Int {
        switch self {
        case .tiny: return 75
        case .base: return 142
        case .small: return 466
        case .medium: return 1500
        case .large: return 3000
        case .largeV2: return 3000
        case .largeV3: return 3000
        }
    }
    
    /// GitHub Release URL
    public var githubReleaseURL: URL {
        // 실제 GitHub 저장소 URL로 변경 필요
        let baseURL = "https://github.com/username/WhisperCoreML/releases/download/v1.0.0"
        let fileName = "\(coreMLModelName).mlmodelc.zip"
        return URL(string: "\(baseURL)/\(fileName)")!
    }
    
    /// 모델 다운로드 URL (Hugging Face)
    public var downloadURL: URL? {
        let baseURL = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main"
        let fileName: String
        
        switch self {
        case .tiny: fileName = "ggml-tiny.en.bin"
        case .base: fileName = "ggml-base.en.bin"
        case .small: fileName = "ggml-small.en.bin"
        case .medium: fileName = "ggml-medium.en.bin"
        case .large: fileName = "ggml-large.bin"
        case .largeV2: fileName = "ggml-large-v2.bin"
        case .largeV3: fileName = "ggml-large-v3.bin"
        }
        
        return URL(string: "\(baseURL)/\(fileName)")
    }
    
    /// CoreML 모델 파일 이름
    public var coreMLModelName: String {
        "whisper-\(rawValue)"
    }
    
    /// 모델 파일 로컬 저장 경로
    public func localModelPath() -> URL {
        let fileManager = FileManager.default
        let appSupportURL = try! fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let modelDirectory = appSupportURL.appendingPathComponent("WhisperCoreML/Models", isDirectory: true)
        
        // 디렉토리가 없으면 생성
        if !fileManager.fileExists(atPath: modelDirectory.path) {
            try? fileManager.createDirectory(at: modelDirectory, withIntermediateDirectories: true)
        }
        
        return modelDirectory.appendingPathComponent("\(coreMLModelName).mlpackage")
    }
    
    /// 모델이 로컬에 존재하는지 확인
    public func modelExists() -> Bool {
        FileManager.default.fileExists(atPath: localModelPath().path)
    }
    
    /// 모델 파일 크기 (바이트 단위)
    public func modelFileSize() -> Int64? {
        let path = localModelPath().path
        guard FileManager.default.fileExists(atPath: path) else {
            return nil
        }
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: path)
            return attributes[.size] as? Int64
        } catch {
            return nil
        }
    }
} 