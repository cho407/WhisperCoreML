import Foundation
import Combine

/// 다운로드 진행 상황 정보
public struct DownloadProgress {
    /// 다운로드된 바이트 수
    public let bytesDownloaded: Int64
    
    /// 총 바이트 수
    public let totalBytes: Int64
    
    /// 진행률 (0.0 ~ 1.0)
    public let progress: Double
    
    /// 초기화 메서드
    public init(bytesDownloaded: Int64, totalBytes: Int64) {
        self.bytesDownloaded = bytesDownloaded
        self.totalBytes = totalBytes
        self.progress = totalBytes > 0 ? Double(bytesDownloaded) / Double(totalBytes) : 0
    }
}

/// 다운로드 오류
public enum DownloadError: Error, LocalizedError {
    /// 네트워크 오류
    case networkError(String)
    
    /// 파일 시스템 오류
    case fileSystemError(String)
    
    /// 다운로드 취소됨
    case cancelled
    
    /// 오류 설명
    public var errorDescription: String? {
        switch self {
        case .networkError(let message):
            return "네트워크 오류: \(message)"
        case .fileSystemError(let message):
            return "파일 시스템 오류: \(message)"
        case .cancelled:
            return "다운로드가 취소되었습니다."
        }
    }
}

/// 파일 다운로드 관리자
public class DownloadManager {
    /// 싱글톤 인스턴스
    public static let shared = DownloadManager()
    
    /// 활성 다운로드 작업
    private var activeDownloads: [URL: URLSessionDownloadTask] = [:]
    
    /// 다운로드 진행 상황 관찰자
    private var progressObservers: [URL: NSKeyValueObservation] = [:]
    
    /// 다운로드 진행 상황 Subject
    private var progressSubjects: [URL: PassthroughSubject<DownloadProgress, DownloadError>] = [:]
    
    /// URL 세션
    private let session: URLSession
    
    /// 초기화 메서드
    private init() {
        let config = URLSessionConfiguration.default
        session = URLSession(configuration: config)
    }
    
    /// 파일 다운로드
    /// - Parameters:
    ///   - url: 다운로드할 파일 URL
    ///   - destination: 저장할 로컬 경로
    /// - Returns: 다운로드 진행 상황 Publisher
    public func downloadFile(from url: URL, to destination: URL) -> AnyPublisher<DownloadProgress, DownloadError> {
        // 이미 진행 중인 다운로드가 있는지 확인
        if let existingSubject = progressSubjects[url] {
            return existingSubject.eraseToAnyPublisher()
        }
        
        // 다운로드 디렉토리 생성
        let directory = destination.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            return Fail(error: .fileSystemError(error.localizedDescription)).eraseToAnyPublisher()
        }
        
        // 다운로드 Subject 생성
        let progressSubject = PassthroughSubject<DownloadProgress, DownloadError>()
        progressSubjects[url] = progressSubject
        
        // 다운로드 작업 생성
        let downloadTask = session.downloadTask(with: url) { [weak self] (tempURL, response, error) in
            guard let self = self else { return }
            
            // 작업 완료 후 정리
            defer {
                self.activeDownloads[url] = nil
                self.progressObservers[url] = nil
                self.progressSubjects[url] = nil
            }
            
            // 오류 처리
            if let error = error as NSError? {
                if error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
                    progressSubject.send(completion: .failure(.cancelled))
                } else {
                    progressSubject.send(completion: .failure(.networkError(error.localizedDescription)))
                }
                return
            }
            
            // 임시 파일 확인
            guard let tempURL = tempURL else {
                progressSubject.send(completion: .failure(.networkError("다운로드된 파일을 찾을 수 없습니다.")))
                return
            }
            
            // 파일 이동
            do {
                // 기존 파일이 있으면 삭제
                if FileManager.default.fileExists(atPath: destination.path) {
                    try FileManager.default.removeItem(at: destination)
                }
                
                // 다운로드한 파일 이동
                try FileManager.default.moveItem(at: tempURL, to: destination)
                progressSubject.send(completion: .finished)
            } catch {
                progressSubject.send(completion: .failure(.fileSystemError(error.localizedDescription)))
            }
        }
        
        // 다운로드 작업 저장
        activeDownloads[url] = downloadTask
        
        // 진행 상황 관찰
        progressObservers[url] = downloadTask.progress.observe(\.fractionCompleted) { [weak self] (progress, _) in
            guard let self = self else { return }
            
            let bytesDownloaded = progress.completedUnitCount
            let totalBytes = progress.totalUnitCount
            
            let progressInfo = DownloadProgress(
                bytesDownloaded: bytesDownloaded,
                totalBytes: totalBytes
            )
            
            self.progressSubjects[url]?.send(progressInfo)
        }
        
        // 다운로드 시작
        downloadTask.resume()
        
        return progressSubject.eraseToAnyPublisher()
    }
    
    /// 다운로드 취소
    /// - Parameter url: 취소할 다운로드 URL
    public func cancelDownload(for url: URL) {
        activeDownloads[url]?.cancel()
        activeDownloads[url] = nil
        progressObservers[url] = nil
        progressSubjects[url]?.send(completion: .failure(.cancelled))
        progressSubjects[url] = nil
    }
    
    /// 모든 다운로드 취소
    public func cancelAllDownloads() {
        for (url, _) in activeDownloads {
            cancelDownload(for: url)
        }
    }
} 