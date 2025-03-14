import Foundation

/// 음성 인식 결과를 저장하는 구조체
struct TranscriptionResult: Identifiable, Equatable, Codable {
    var id = UUID()
    let text: String
    let sourceFile: URL?
    let language: String
    let duration: TimeInterval
    let timestamp: Date
    let modelType: String
    
    static func == (lhs: TranscriptionResult, rhs: TranscriptionResult) -> Bool {
        lhs.id == rhs.id
    }
}

/// 음성 인식 작업 상태
enum TranscriptionState {
    case idle
    case recording
    case processing
    case completed(TranscriptionResult)
    case failed(Error)
    
    var isProcessing: Bool {
        switch self {
        case .processing:
            return true
        default:
            return false
        }
    }
    
    var isRecording: Bool {
        switch self {
        case .recording:
            return true
        default:
            return false
        }
    }
}

/// 오디오 파일 정보
struct AudioFileInfo {
    let url: URL
    let duration: TimeInterval
    let fileSize: Int64
    let createdAt: Date
    
    var formattedDuration: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: duration) ?? "00:00:00"
    }
    
    var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
} 
