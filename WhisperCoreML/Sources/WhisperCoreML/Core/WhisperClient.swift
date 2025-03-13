import Foundation
import Combine
import CoreML

/// Whisper 클라이언트 오류
public enum WhisperClientError: Error, LocalizedError {
    /// 모델 다운로드 실패
    case downloadFailed(String)
    
    /// 네트워크 오류
    case networkError(String)
    
    /// 파일 시스템 오류
    case fileSystemError(String)
    
    /// 모델 초기화 실패
    case initializationFailed(String)
    
    /// 모델 파일 찾을 수 없음
    case modelFileNotFound(String)
    
    /// 모델 로딩 실패
    case modelLoadingFailed(String)
    
    /// 토크나이저 초기화 실패
    case tokenizerInitializationFailed(String)
    
    /// 오류 설명
    public var errorDescription: String? {
        switch self {
        case .downloadFailed(let message):
            return "모델 다운로드 실패: \(message)"
        case .networkError(let message):
            return "네트워크 오류: \(message)"
        case .fileSystemError(let message):
            return "파일 시스템 오류: \(message)"
        case .initializationFailed(let message):
            return "모델 초기화 실패: \(message)"
        case .modelFileNotFound(let message):
            return "모델 파일을 찾을 수 없음: \(message)"
        case .modelLoadingFailed(let message):
            return "모델 로딩 실패: \(message)"
        case .tokenizerInitializationFailed(let message):
            return "토크나이저 초기화 실패: \(message)"
        }
    }
}

/// 모델 다운로드 진행 상태
public struct ModelDownloadProgress {
    /// 다운로드 진행률 (0.0 ~ 1.0)
    public let progress: Double
    
    /// 현재 파일 이름
    public let currentFile: String
    
    /// 다운로드된 바이트 수
    public let downloadedBytes: Int64
    
    /// 총 바이트 수
    public let totalBytes: Int64
    
    /// 상태 메시지
    public let message: String
    
    /// 초기화
    public init(progress: Double, currentFile: String, downloadedBytes: Int64, totalBytes: Int64, message: String) {
        self.progress = progress
        self.currentFile = currentFile
        self.downloadedBytes = downloadedBytes
        self.totalBytes = totalBytes
        self.message = message
    }
}

/// Whisper 클라이언트 프로토콜
public protocol WhisperClientProtocol {
    /// 모델 초기화
    /// - Parameter modelType: 모델 타입
    /// - Returns: 초기화된 모델 객체
    func initializeModel(modelType: String) async throws -> Any
    
    /// 모델 다운로드
    /// - Parameters:
    ///   - modelType: 모델 타입
    ///   - progressHandler: 진행 상황 핸들러
    /// - Returns: 다운로드 상태를 전달하는 퍼블리셔
    func downloadModel(
        _ modelType: String,
        progressHandler: @escaping (ModelDownloadProgress) -> Void
    ) -> AnyPublisher<Void, WhisperClientError>
    
    /// 모든 공통 파일 다운로드
    /// - Parameter progressHandler: 진행 상황 핸들러
    /// - Returns: 다운로드 상태를 전달하는 퍼블리셔
    func downloadCommonFiles(
        progressHandler: @escaping (ModelDownloadProgress) -> Void
    ) -> AnyPublisher<Void, WhisperClientError>
    
    /// 사용 가능한 모델 목록 반환
    /// - Returns: 로컬에 존재하는 모델 타입 목록
    func getAvailableModels() async -> [String]
    
    /// 모델 삭제
    /// - Parameter modelType: 삭제할 모델 타입
    /// - Returns: 성공 여부
    func deleteModel(_ modelType: String) async -> Bool
}

/// Whisper 클라이언트 클래스
public class WhisperClient: WhisperClientProtocol {
    /// 공유 인스턴스
    public static let shared = WhisperClient()
    
    /// 파일 매니저
    private let fileManager = FileManager.default
    
    /// 초기화 메서드
    private init() {}
    
    /// 모델 초기화
    /// - Parameter modelType: 모델 타입
    /// - Returns: 초기화된 모델 객체
    public func initializeModel(modelType: String) async throws -> Any {
        do {
            let bridgeManager = BridgeManager.shared
            return try await bridgeManager.modelBridge.initializeModel(modelType: modelType)
        } catch let error {
            // ModelError를 WhisperClientError로 변환
            switch error {
            case _ where error.localizedDescription.contains("모델 파일을 찾을 수 없습니다"):
                throw WhisperClientError.modelFileNotFound(error.localizedDescription)
            case _ where error.localizedDescription.contains("로드 실패"):
                throw WhisperClientError.modelLoadingFailed(error.localizedDescription)
            default:
                throw WhisperClientError.initializationFailed(error.localizedDescription)
            }
        }
    }
    
    /// 모델 다운로드
    /// - Parameters:
    ///   - modelType: 모델 타입
    ///   - progressHandler: 진행 상황 핸들러
    /// - Returns: 다운로드 상태를 전달하는 퍼블리셔
    public func downloadModel(
        _ modelType: String,
        progressHandler: @escaping (ModelDownloadProgress) -> Void
    ) -> AnyPublisher<Void, WhisperClientError> {
        // Tiny 모델은 패키지에 내장되어 있으므로 다운로드 불필요
        if modelType == "tiny" {
            return Just(()).setFailureType(to: WhisperClientError.self).eraseToAnyPublisher()
        }
        
        let subject = PassthroughSubject<Void, WhisperClientError>()
        
        // 모델 타입 브릿지
        let modelTypeBridge = BridgeManager.shared.modelTypeBridge
        
        // 모델 디렉토리 생성
        guard let modelDirectory = modelTypeBridge.getModelDirectory(for: modelType) else {
            subject.send(completion: .failure(.fileSystemError("모델 디렉토리를 생성할 수 없습니다.")))
            return subject.eraseToAnyPublisher()
        }
        
        // 다운로드할 파일 목록
        var filesToDownload: [(URL, URL, String)] = []
        
        // 인코더 모델
        if let remoteURL = modelTypeBridge.getEncoderModelURL(for: modelType),
           let localURL = modelTypeBridge.getLocalEncoderModelPath(for: modelType) {
            filesToDownload.append((remoteURL, localURL, "인코더 모델"))
        } else {
            subject.send(completion: .failure(.initializationFailed("인코더 모델 URL을 가져올 수 없습니다.")))
            return subject.eraseToAnyPublisher()
        }
        
        // 디코더 모델
        if let remoteURL = modelTypeBridge.getDecoderModelURL(for: modelType),
           let localURL = modelTypeBridge.getLocalDecoderModelPath(for: modelType) {
            filesToDownload.append((remoteURL, localURL, "디코더 모델"))
        } else {
            subject.send(completion: .failure(.initializationFailed("디코더 모델 URL을 가져올 수 없습니다.")))
            return subject.eraseToAnyPublisher()
        }
        
        // 설정 파일
        if let remoteURL = modelTypeBridge.getConfigFileURL(for: modelType),
           let localURL = modelTypeBridge.getLocalConfigFilePath(for: modelType) {
            filesToDownload.append((remoteURL, localURL, "모델 설정"))
        } else {
            subject.send(completion: .failure(.initializationFailed("설정 파일 URL을 가져올 수 없습니다.")))
            return subject.eraseToAnyPublisher()
        }
        
        // 전처리 설정 파일
        if let remoteURL = modelTypeBridge.getPreprocessorConfigURL(for: modelType) {
            let localURL = modelDirectory.appendingPathComponent("preprocessor_config.json")
            filesToDownload.append((remoteURL, localURL, "전처리 설정"))
        }
        
        // 생성 설정 파일
        if let remoteURL = modelTypeBridge.getGenerationConfigURL(for: modelType) {
            let localURL = modelDirectory.appendingPathComponent("generation_config.json")
            filesToDownload.append((remoteURL, localURL, "생성 설정"))
        }
        
        // 백그라운드 작업으로 다운로드 시작
        Task {
            do {
                var totalDownloaded: Int64 = 0
                let totalFiles = filesToDownload.count
                
                // 각 파일 다운로드
                for (index, (remoteURL, localURL, fileDescription)) in filesToDownload.enumerated() {
                    // 이미 존재하는 파일은 스킵
                    if fileManager.fileExists(atPath: localURL.path) {
                        // 파일 크기 계산
                        if let attributes = try? fileManager.attributesOfItem(atPath: localURL.path),
                           let fileSize = attributes[.size] as? Int64 {
                            totalDownloaded += fileSize
                        }
                        
                        // 진행 상황 업데이트
                        let progress = Double(index) / Double(totalFiles)
                        progressHandler(ModelDownloadProgress(
                            progress: progress,
                            currentFile: fileDescription,
                            downloadedBytes: totalDownloaded,
                            totalBytes: 0,
                            message: "\(fileDescription) 파일이 이미 존재합니다."
                        ))
                        continue
                    }
                    
                    // 진행 상황 업데이트
                    progressHandler(ModelDownloadProgress(
                        progress: Double(index) / Double(totalFiles),
                        currentFile: fileDescription,
                        downloadedBytes: totalDownloaded,
                        totalBytes: 0,
                        message: "\(fileDescription) 다운로드 중..."
                    ))
                    
                    // 파일 다운로드
                    let request = URLRequest(url: remoteURL, timeoutInterval: 60)
                    let (tempURL, response) = try await URLSession.shared.download(for: request)
                    
                    guard let httpResponse = response as? HTTPURLResponse,
                          (200...299).contains(httpResponse.statusCode) else {
                        throw WhisperClientError.networkError("서버 응답 오류")
                    }
                    
                    // 임시 파일을 목적지로 이동
                    try fileManager.moveItem(at: tempURL, to: localURL)
                    
                    // 파일 크기 계산
                    if let attributes = try? fileManager.attributesOfItem(atPath: localURL.path),
                       let fileSize = attributes[.size] as? Int64 {
                        totalDownloaded += fileSize
                    }
                }
                
                // 다운로드 완료
                progressHandler(ModelDownloadProgress(
                    progress: 1.0,
                    currentFile: "완료",
                    downloadedBytes: totalDownloaded,
                    totalBytes: totalDownloaded,
                    message: "모델 다운로드가 완료되었습니다."
                ))
                
                subject.send(())
                subject.send(completion: .finished)
            } catch {
                subject.send(completion: .failure(.downloadFailed(error.localizedDescription)))
            }
        }
        
        return subject.eraseToAnyPublisher()
    }
    
    /// 공통 파일 다운로드
    /// - Parameter progressHandler: 진행 상황 핸들러
    /// - Returns: 다운로드 상태를 전달하는 퍼블리셔
    public func downloadCommonFiles(
        progressHandler: @escaping (ModelDownloadProgress) -> Void
    ) -> AnyPublisher<Void, WhisperClientError> {
        let subject = PassthroughSubject<Void, WhisperClientError>()
        
        // 모델 타입 브릿지
        let modelTypeBridge = BridgeManager.shared.modelTypeBridge
        
        // 공통 파일 디렉토리
        let commonFilesDirectory = BridgeManager.shared.commonFilesDirectory
        
        // 다운로드할 파일 목록
        var filesToDownload: [(URL, URL, String)] = []
        
        // 토크나이저 파일
        if let remoteURL = modelTypeBridge.tokenizerFileURL {
            let localURL = commonFilesDirectory.appendingPathComponent("tokenizer.json")
            filesToDownload.append((remoteURL, localURL, "토크나이저"))
        }
        
        // 어휘 파일
        if let remoteURL = modelTypeBridge.vocabFileURL {
            let localURL = commonFilesDirectory.appendingPathComponent("vocab.json")
            filesToDownload.append((remoteURL, localURL, "어휘 사전"))
        }
        
        // 토크나이저 설정 파일
        if let remoteURL = modelTypeBridge.tokenizerConfigURL {
            let localURL = commonFilesDirectory.appendingPathComponent("tokenizer_config.json")
            filesToDownload.append((remoteURL, localURL, "토크나이저 설정"))
        }
        
        // 특수 토큰 매핑
        if let remoteURL = modelTypeBridge.specialTokensMapURL {
            let localURL = commonFilesDirectory.appendingPathComponent("special_tokens_map.json")
            filesToDownload.append((remoteURL, localURL, "특수 토큰 매핑"))
        }
        
        // 병합 규칙
        if let remoteURL = modelTypeBridge.mergesFileURL {
            let localURL = commonFilesDirectory.appendingPathComponent("merges.txt")
            filesToDownload.append((remoteURL, localURL, "BPE 병합 규칙"))
        }
        
        // 정규화 설정
        if let remoteURL = modelTypeBridge.normalizerFileURL {
            let localURL = commonFilesDirectory.appendingPathComponent("normalizer.json")
            filesToDownload.append((remoteURL, localURL, "정규화 설정"))
        }
        
        // 필수 URL이 모두 있는지 확인
        if filesToDownload.isEmpty {
            subject.send(completion: .failure(.initializationFailed("다운로드할 파일 URL을 가져올 수 없습니다.")))
            return subject.eraseToAnyPublisher()
        }
        
        // 백그라운드 작업으로 다운로드 시작
        Task {
            do {
                var totalDownloaded: Int64 = 0
                let totalFiles = filesToDownload.count
                
                // 각 파일 다운로드
                for (index, (remoteURL, localURL, fileDescription)) in filesToDownload.enumerated() {
                    // 이미 존재하는 파일은 스킵
                    if fileManager.fileExists(atPath: localURL.path) {
                        // 파일 크기 계산
                        if let attributes = try? fileManager.attributesOfItem(atPath: localURL.path),
                           let fileSize = attributes[.size] as? Int64 {
                            totalDownloaded += fileSize
                        }
                        
                        // 진행 상황 업데이트
                        let progress = Double(index) / Double(totalFiles)
                        progressHandler(ModelDownloadProgress(
                            progress: progress,
                            currentFile: fileDescription,
                            downloadedBytes: totalDownloaded,
                            totalBytes: 0,
                            message: "\(fileDescription) 파일이 이미 존재합니다."
                        ))
                        continue
                    }
                    
                    // 진행 상황 업데이트
                    progressHandler(ModelDownloadProgress(
                        progress: Double(index) / Double(totalFiles),
                        currentFile: fileDescription,
                        downloadedBytes: totalDownloaded,
                        totalBytes: 0,
                        message: "\(fileDescription) 다운로드 중..."
                    ))
                    
                    // 파일 다운로드
                    let request = URLRequest(url: remoteURL, timeoutInterval: 30)
                    let (tempURL, response) = try await URLSession.shared.download(for: request)
                    
                    guard let httpResponse = response as? HTTPURLResponse,
                          (200...299).contains(httpResponse.statusCode) else {
                        throw WhisperClientError.networkError("서버 응답 오류")
                    }
                    
                    // 임시 파일을 목적지로 이동
                    try fileManager.moveItem(at: tempURL, to: localURL)
                    
                    // 파일 크기 계산
                    if let attributes = try? fileManager.attributesOfItem(atPath: localURL.path),
                       let fileSize = attributes[.size] as? Int64 {
                        totalDownloaded += fileSize
                    }
                }
                
                // 다운로드 완료
                progressHandler(ModelDownloadProgress(
                    progress: 1.0,
                    currentFile: "완료",
                    downloadedBytes: totalDownloaded,
                    totalBytes: totalDownloaded,
                    message: "공통 파일 다운로드가 완료되었습니다."
                ))
                
                subject.send(())
                subject.send(completion: .finished)
            } catch {
                subject.send(completion: .failure(.downloadFailed(error.localizedDescription)))
            }
        }
        
        return subject.eraseToAnyPublisher()
    }
    
    /// 사용 가능한 모델 목록 반환
    /// - Returns: 로컬에 존재하는 모델 타입 목록
    public func getAvailableModels() async -> [String] {
        var availableModels: [String] = []
        
        // 모델 타입 브릿지
        let modelTypeBridge = BridgeManager.shared.modelTypeBridge
        
        // 항상 Tiny 모델을 포함 (내장되어 있음)
        availableModels.append("tiny")
        
        // 다운로드된 모델 확인
        for modelType in modelTypeBridge.allModelTypeStrings where modelType != "tiny" {
            if modelTypeBridge.allRequiredFilesExist(for: modelType) {
                availableModels.append(modelType)
            }
        }
        
        return availableModels
    }
    
    /// 모델 삭제
    /// - Parameter modelType: 삭제할 모델 타입
    /// - Returns: 성공 여부
    public func deleteModel(_ modelType: String) async -> Bool {
        // Tiny 모델은 내장되어 있으므로 삭제 불가
        if modelType == "tiny" {
            return false
        }
        
        // 모델 타입 브릿지
        let modelTypeBridge = BridgeManager.shared.modelTypeBridge
        
        // 모델 디렉토리
        guard let modelDirectory = modelTypeBridge.getModelDirectory(for: modelType) else {
            return false
        }
        
        do {
            if fileManager.fileExists(atPath: modelDirectory.path) {
                try fileManager.removeItem(at: modelDirectory)
            }
            return true
        } catch {
            print("모델 삭제 실패: \(error.localizedDescription)")
            return false
        }
    }
} 