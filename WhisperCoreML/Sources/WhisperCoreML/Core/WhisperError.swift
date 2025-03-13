import Foundation

/// Whisper 관련 에러
public enum WhisperError: LocalizedError {
    // 모델 관련 에러
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
    case modelFileNotFound(String)
    
    // 오디오 처리 관련 에러
    case audioProcessingFailed(String)
    case invalidAudioFormat(String)
    case audioStreamError(String)
    case audioEngineError(String)
    
    // 네트워크 관련 에러
    case networkError(String)
    case downloadFailed(String)
    case networkUnavailable
    case connectionTimeout(TimeInterval)
    case serverError(Int)
    
    // 파일 시스템 관련 에러
    case fileSystemError(String)
    case fileNotFound(String)
    case invalidFilePath(String)
    case insufficientDiskSpace
    case diskWriteError(path: String)
    case diskReadError(path: String)
    
    // 토크나이저 관련 에러
    case tokenizerError(String)
    case invalidTokenSequence(String)
    
    // 배치 처리 관련 에러
    case batchProcessingError(String)
    case concurrencyError(String)
    
    // 일반 에러
    case invalidConfiguration(String)
    case internalError(String)
    case unknown(String)
    
    public var errorDescription: String? {
        switch self {
        // 모델 관련 에러
        case .modelNotFound:
            return "모델 파일을 찾을 수 없습니다."
        case .modelLoadFailed(let reason):
            return "모델 로드 실패: \(reason)"
        case .modelLoadingFailed(let error):
            return "모델 로딩 실패: \(error.localizedDescription)"
        case .modelNotLoaded:
            return "모델이 로드되지 않았습니다."
        case .invalidModelURL:
            return "잘못된 모델 URL입니다."
        case .modelInputPreparationFailed(let reason):
            return "모델 입력 준비 실패: \(reason)"
        case .modelOutputProcessingFailed(let reason):
            return "모델 출력 처리 실패: \(reason)"
        case .modelUnavailableOffline(let requested, let alternative):
            if let alt = alternative {
                return "요청한 모델(\(requested.displayName))은 오프라인에서 사용할 수 없습니다. 대신 \(alt.displayName) 모델을 사용할 수 있습니다."
            } else {
                return "요청한 모델(\(requested.displayName))은 오프라인에서 사용할 수 없습니다."
            }
        case .noModelsAvailableOffline:
            return "오프라인에서 사용 가능한 모델이 없습니다."
        case .modelVersionMismatch(let expected, let found):
            return "모델 버전 불일치: 예상 버전 \(expected), 발견된 버전 \(found)"
        case .modelCorrupted(let reason):
            return "모델 파일이 손상되었습니다: \(reason)"
            
        // 오디오 처리 관련 에러
        case .audioProcessingFailed(let reason):
            return "오디오 처리 실패: \(reason)"
        case .invalidAudioFormat(let reason):
            return "잘못된 오디오 형식: \(reason)"
        case .audioStreamError(let reason):
            return "오디오 스트림 에러: \(reason)"
        case .audioEngineError(let reason):
            return "오디오 엔진 에러: \(reason)"
            
        // 네트워크 관련 에러
        case .networkError(let reason):
            return "네트워크 에러: \(reason)"
        case .downloadFailed(let reason):
            return "다운로드 실패: \(reason)"
        case .networkUnavailable:
            return "네트워크에 연결할 수 없습니다."
        case .connectionTimeout(let timeout):
            return "연결 시간 초과: \(String(format: "%.1f", timeout))초"
        case .serverError(let code):
            return "서버 오류 (코드: \(code))"
            
        // 파일 시스템 관련 에러
        case .fileSystemError(let reason):
            return "파일 시스템 에러: \(reason)"
        case .fileNotFound(let reason):
            return "파일을 찾을 수 없음: \(reason)"
        case .invalidFilePath(let reason):
            return "잘못된 파일 경로: \(reason)"
        case .insufficientDiskSpace:
            return "디스크 공간이 부족합니다."
        case .diskWriteError(let path):
            return "디스크 쓰기 오류: \(path)"
        case .diskReadError(let path):
            return "디스크 읽기 오류: \(path)"
            
        // 토크나이저 관련 에러
        case .tokenizerError(let reason):
            return "토크나이저 에러: \(reason)"
        case .invalidTokenSequence(let reason):
            return "잘못된 토큰 시퀀스: \(reason)"
            
        // 배치 처리 관련 에러
        case .batchProcessingError(let reason):
            return "배치 처리 에러: \(reason)"
        case .concurrencyError(let reason):
            return "동시성 처리 에러: \(reason)"
            
        // 일반 에러
        case .invalidConfiguration(let reason):
            return "잘못된 설정: \(reason)"
        case .internalError(let reason):
            return "내부 에러: \(reason)"
        case .modelFileNotFound(let reason):
            return "모델 파일 없음: \(reason)"
        case .unknown(let reason):
            return "알 수 없는 에러: \(reason)"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .modelNotFound:
            return "모델 파일이 올바른 위치에 있는지 확인하세요."
        case .modelLoadFailed:
            return "모델 파일이 손상되지 않았는지 확인하고 다시 다운로드해보세요."
        case .modelNotLoaded:
            return "모델을 먼저 로드한 후 사용하세요."
        case .invalidModelURL:
            return "올바른 모델 URL을 제공하세요."
        case .modelUnavailableOffline(_, let alternative):
            if let alt = alternative {
                return "네트워크에 연결하여 모델을 다운로드하거나, 대체 모델(\(alt.displayName))을 사용하세요."
            } else {
                return "네트워크에 연결하여 모델을 다운로드하세요."
            }
        case .noModelsAvailableOffline:
            return "네트워크에 연결하여 최소한 하나의 모델을 다운로드하세요."
        case .modelVersionMismatch:
            return "최신 버전의 모델을 다운로드하세요."
        case .modelCorrupted:
            return "모델 파일을 삭제하고 다시 다운로드하세요."
        case .audioProcessingFailed:
            return "지원되는 오디오 형식인지 확인하세요."
        case .networkUnavailable:
            return "네트워크 연결을 확인하고 다시 시도하세요."
        case .connectionTimeout:
            return "네트워크 상태를 확인하고 다시 시도하세요. 안정적인 연결에서 시도하는 것이 좋습니다."
        case .serverError:
            return "잠시 후 다시 시도하세요. 문제가 지속되면 개발자에게 문의하세요."
        case .insufficientDiskSpace:
            return "불필요한 파일을 삭제하여 디스크 공간을 확보하세요."
        case .fileSystemError:
            return "디스크 공간과 권한을 확인하세요."
        default:
            return "문제가 지속되면 개발자에게 문의하세요."
        }
    }
    
    public var failureReason: String? {
        switch self {
        case .modelLoadFailed(let reason),
             .modelInputPreparationFailed(let reason),
             .modelOutputProcessingFailed(let reason),
             .audioProcessingFailed(let reason),
             .networkError(let reason),
             .fileSystemError(let reason),
             .unknown(let reason):
            return reason
        case .modelCorrupted(let reason):
            return reason
        case .connectionTimeout(let timeout):
            return "연결 시간(\(String(format: "%.1f", timeout))초)이 초과되었습니다."
        case .serverError(let code):
            return "서버가 \(code) 오류 코드를 반환했습니다."
        case .insufficientDiskSpace:
            return "디스크 공간이 부족하여 작업을 완료할 수 없습니다."
        default:
            return nil
        }
    }
}

/// 오류 복구 옵션
public struct ErrorRecoveryOptions {
    /// 재시도 가능 여부
    public let canRetry: Bool
    
    /// 제안된 복구 작업
    public let suggestedAction: RecoveryAction?
    
    /// 사용자 메시지
    public let message: String
    
    /// 복구 작업 유형
    public enum RecoveryAction {
        /// 다운로드 재시도
        case retryDownload
        /// 대체 모델 사용
        case useAlternativeModel(WhisperModelType)
        /// 캐시 정리
        case clearCache
        /// 네트워크 연결 확인
        case checkNetworkConnection
        /// 디스크 공간 확보
        case freeDiskSpace
    }
}

extension WhisperError {
    /// 오류 복구 옵션
    public var recoveryOptions: ErrorRecoveryOptions {
        switch self {
        case .networkUnavailable:
            return ErrorRecoveryOptions(
                canRetry: true,
                suggestedAction: .checkNetworkConnection,
                message: "네트워크 연결을 확인하고 다시 시도하세요."
            )
        case .insufficientDiskSpace:
            return ErrorRecoveryOptions(
                canRetry: true,
                suggestedAction: .freeDiskSpace,
                message: "디스크 공간이 부족합니다. 불필요한 파일을 삭제하고 다시 시도하세요."
            )
        case .modelUnavailableOffline(let requested, let alternative):
            if let alt = alternative {
                return ErrorRecoveryOptions(
                    canRetry: false,
                    suggestedAction: .useAlternativeModel(alt),
                    message: "요청한 모델(\(requested.displayName))은 오프라인에서 사용할 수 없습니다. 대신 \(alt.displayName) 모델을 사용할 수 있습니다."
                )
            } else {
                return ErrorRecoveryOptions(
                    canRetry: true,
                    suggestedAction: .retryDownload,
                    message: "요청한 모델(\(requested.displayName))은 오프라인에서 사용할 수 없습니다. 네트워크 연결 후 다시 시도하세요."
                )
            }
        case .downloadFailed:
            return ErrorRecoveryOptions(
                canRetry: true,
                suggestedAction: .retryDownload,
                message: "다운로드에 실패했습니다. 다시 시도하세요."
            )
        case .modelCorrupted:
            return ErrorRecoveryOptions(
                canRetry: true,
                suggestedAction: .retryDownload,
                message: "모델 파일이 손상되었습니다. 다시 다운로드하세요."
            )
        default:
            return ErrorRecoveryOptions(
                canRetry: true,
                suggestedAction: nil,
                message: "문제가 지속되면 개발자에게 문의하세요."
            )
        }
    }
}

/// 에러 복구 도우미
public struct ErrorRecoveryHelper {
    /// 에러 복구 시도
    /// - Parameter error: 발생한 에러
    /// - Returns: 복구 성공 여부
    public static func attemptRecovery(from error: WhisperError) async -> Bool {
        switch error {
        case .modelNotFound, .modelLoadFailed, .modelCorrupted:
            // 모델 재다운로드 시도
            return await attemptModelRedownload()
            
        case .audioProcessingFailed:
            // 오디오 처리 재시도
            return await attemptAudioProcessingRecovery()
            
        case .networkError, .networkUnavailable, .connectionTimeout:
            // 네트워크 재연결 시도
            return await attemptNetworkRecovery()
            
        case .insufficientDiskSpace:
            // 디스크 공간 확보 시도
            return await attemptDiskSpaceRecovery()
            
        default:
            return false
        }
    }
    
    private static func attemptModelRedownload() async -> Bool {
        // 모델 재다운로드 로직 구현
        return false
    }
    
    private static func attemptAudioProcessingRecovery() async -> Bool {
        // 오디오 처리 복구 로직 구현
        return false
    }
    
    private static func attemptNetworkRecovery() async -> Bool {
        // 네트워크 복구 로직 구현
        // 네트워크 상태 확인
        let networkStatus = NetworkMonitor.checkCurrentStatus()
        return networkStatus.isConnected
    }
    
    private static func attemptDiskSpaceRecovery() async -> Bool {
        // 디스크 공간 확보 로직 구현
        // 임시 파일 정리 등
        return false
    }
} 
