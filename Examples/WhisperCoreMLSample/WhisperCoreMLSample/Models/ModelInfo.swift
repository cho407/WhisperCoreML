import Foundation
import WhisperCoreML

/// Whisper 모델 정보를 저장하는 구조체
struct ModelInfo: Identifiable, Equatable {
    let id = UUID()
    let type: WhisperModelType
    let isDownloaded: Bool
    let downloadProgress: Double?
    let isBuiltIn: Bool
    
    var displayName: String {
        type.displayName
    }
    
    var sizeInMB: Int {
        type.sizeInMB
    }
    
    var formattedSize: String {
        "\(sizeInMB) MB"
    }
    
    static func == (lhs: ModelInfo, rhs: ModelInfo) -> Bool {
        lhs.type == rhs.type
    }
    
    /// 다운로드 상태 텍스트
    var statusText: String {
        if isBuiltIn {
            return "내장됨"
        }
        
        if isDownloaded {
            return "다운로드됨"
        }
        
        if let progress = downloadProgress {
            let percent = Int(progress * 100)
            return "다운로드 중... \(percent)%"
        }
        
        return "다운로드 필요"
    }
}

/// 모델 다운로드 상태
enum ModelDownloadState {
    case notDownloaded
    case downloading(progress: Double)
    case downloaded
    case failed(Error)
}

/// 언어 옵션
enum LanguageOption: String, CaseIterable, Identifiable {
    case autoDetect = "auto"
    case korean = "ko"
    case english = "en"
    case japanese = "ja"
    case chinese = "zh"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case italian = "it"
    case russian = "ru"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .autoDetect: return "자동 감지"
        case .korean: return "한국어"
        case .english: return "영어"
        case .japanese: return "일본어"
        case .chinese: return "중국어"
        case .spanish: return "스페인어"
        case .french: return "프랑스어"
        case .german: return "독일어"
        case .italian: return "이탈리아어"
        case .russian: return "러시아어"
        }
    }
} 