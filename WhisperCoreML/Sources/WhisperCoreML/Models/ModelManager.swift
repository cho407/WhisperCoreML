import Foundation
import Combine
#if canImport(Zip)
import Zip
#endif
import Network

/// 모델 다운로드 진행 상태 (상세)
public struct DetailedModelDownloadProgress: Equatable {
    /// 다운로드 진행률 (0.0 ~ 1.0)
    public let progress: Double
    
    /// 다운로드된 바이트 수
    public let downloadedBytes: Int64
    
    /// 총 바이트 수
    public let totalBytes: Int64
    
    /// 다운로드 속도 (bytes/sec)
    public let downloadSpeed: Double
    
    /// 남은 예상 시간 (초)
    public let estimatedTimeRemaining: TimeInterval
    
    /// 현재 상태 메시지
    public let statusMessage: String
}

/// 모델 다운로드 상태
public enum ModelDownloadState {
    /// 대기 중
    case idle
    
    /// 다운로드 중
    case downloading(DetailedModelDownloadProgress)
    
    /// 압축 해제 중
    case extracting(Double)
    
    /// 완료됨
    case completed(URL)
    
    /// 실패
    case failed(Error)
}

/// 모델 캐시 정보
public struct ModelCacheInfo: Codable {
    /// 모델 타입
    public let modelType: WhisperModelType
    
    /// 다운로드 날짜
    public let downloadDate: Date
    
    /// 마지막 사용 날짜
    public var lastUsedDate: Date
    
    /// 사용 횟수
    public var usageCount: Int
    
    /// 파일 크기 (바이트)
    public let fileSize: Int64
    
    /// 모델 버전
    public let version: String
    
    /// 체크섬
    public let checksum: String
    
    /// 기본 초기화 메서드
    public init(
        modelType: WhisperModelType,
        downloadDate: Date,
        lastUsedDate: Date,
        usageCount: Int,
        fileSize: Int64,
        version: String,
        checksum: String
    ) {
        self.modelType = modelType
        self.downloadDate = downloadDate
        self.lastUsedDate = lastUsedDate
        self.usageCount = usageCount
        self.fileSize = fileSize
        self.version = version
        self.checksum = checksum
    }
    
    // Codable 지원을 위한 CodingKeys
    private enum CodingKeys: String, CodingKey {
        case modelType, downloadDate, lastUsedDate, usageCount, fileSize, version, checksum
    }
    
    // Decodable 구현
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let modelTypeString = try container.decode(String.self, forKey: .modelType)
        
        guard let modelType = WhisperModelType(rawValue: modelTypeString) else {
            throw DecodingError.dataCorruptedError(
                forKey: .modelType,
                in: container,
                debugDescription: "Invalid model type: \(modelTypeString)"
            )
        }
        
        self.modelType = modelType
        self.downloadDate = try container.decode(Date.self, forKey: .downloadDate)
        self.lastUsedDate = try container.decode(Date.self, forKey: .lastUsedDate)
        self.usageCount = try container.decode(Int.self, forKey: .usageCount)
        self.fileSize = try container.decode(Int64.self, forKey: .fileSize)
        self.version = try container.decode(String.self, forKey: .version)
        self.checksum = try container.decode(String.self, forKey: .checksum)
    }
    
    // Encodable 구현
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(modelType.rawValue, forKey: .modelType)
        try container.encode(downloadDate, forKey: .downloadDate)
        try container.encode(lastUsedDate, forKey: .lastUsedDate)
        try container.encode(usageCount, forKey: .usageCount)
        try container.encode(fileSize, forKey: .fileSize)
        try container.encode(version, forKey: .version)
        try container.encode(checksum, forKey: .checksum)
    }
}

/// Whisper 모델 관리자
public actor ModelManager {
    /// 싱글톤 인스턴스
    public static let shared = ModelManager()
    
    /// 모델 저장 디렉토리
    private let modelsDirectory: URL
    
    /// 캐시 정보 저장 파일
    private let cacheInfoFile: URL
    
    /// 캐시 정보
    private var cacheInfo: [String: ModelCacheInfo] = [:]
    
    /// 현재 다운로드 작업
    private var currentDownloadTask: Task<URL, Error>?
    
    /// 다운로드 상태 발행자
    private var downloadStateSubject = PassthroughSubject<ModelDownloadState, Never>()
    
    /// 최대 재시도 횟수
    private let maxRetryAttempts = 3
    
    /// 재시도 대기 시간 (초)
    private let retryDelay: TimeInterval = 2.0
    
    /// 최소 필요 디스크 공간 (20% 여유 공간)
    private let minimumDiskSpace: Int64 = 1024 * 1024 * 1024 // 1GB
    
    /// 다운로드 상태 발행자 (외부용)
    public var downloadStatePublisher: AnyPublisher<ModelDownloadState, Never> {
        downloadStateSubject.eraseToAnyPublisher()
    }
    
    /// 최대 캐시 크기 (기본값: 5GB)
    public var maxCacheSize: Int64 = 5 * 1024 * 1024 * 1024
    
    /// 초기화
    /// - Note: Swift 6에서는 액터 격리된 메서드 호출 시 비동기 컨텍스트가 필요합니다.
    ///         따라서 `loadCacheInfo()`와 같은 액터 메서드는 Task 블록 내에서 await와 함께 호출해야 합니다.
    private init() {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.modelsDirectory = appSupport.appendingPathComponent("WhisperCoreML/Models", isDirectory: true)
        self.cacheInfoFile = appSupport.appendingPathComponent("WhisperCoreML/modelCache.json")
        
        // 디렉토리 생성
        try? fileManager.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
        
        // 네트워크 모니터링 시작
        NetworkMonitor.startMonitorIfNeeded()
        
        // 캐시 정보 로드
        Task {
            await loadCacheInfo()
        }
    }
    
    /// 캐시 정보 로드
    private func loadCacheInfo() {
        guard FileManager.default.fileExists(atPath: cacheInfoFile.path) else {
            return
        }
        
        do {
            let data = try Data(contentsOf: cacheInfoFile)
            let decoder = JSONDecoder()
            let cacheInfoArray = try decoder.decode([ModelCacheInfo].self, from: data)
            
            // 배열을 딕셔너리로 변환
            self.cacheInfo = Dictionary(uniqueKeysWithValues: cacheInfoArray.map { 
                ($0.modelType.rawValue, $0) 
            })
        } catch {
            print("캐시 정보 로드 실패: \(error)")
        }
    }
    
    /// 캐시 정보 저장
    private func saveCacheInfo() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(Array(cacheInfo.values))
            try data.write(to: cacheInfoFile)
        } catch {
            print("캐시 정보 저장 실패: \(error)")
        }
    }
    
    /// 모델 로드
    /// - Parameter type: 모델 타입
    /// - Returns: 모델 URL
    public func loadModel(_ type: WhisperModelType) async throws -> URL {
        let modelURL = modelPath(for: type)
        
        // 모델이 이미 존재하는지 확인
        if FileManager.default.fileExists(atPath: modelURL.path) {
            // 캐시 정보 업데이트
            updateCacheInfo(for: type)
            return modelURL
        }
        
        // 모델 다운로드
        return try await downloadModel(type)
    }
    
    /// 모델 경로
    /// - Parameter type: 모델 타입
    /// - Returns: 모델 경로
    public func modelPath(for type: WhisperModelType) -> URL {
        modelsDirectory.appendingPathComponent("\(type.coreMLModelName).mlmodelc")
    }
    
    /// 모델 다운로드
    /// - Parameter type: 모델 타입
    /// - Returns: 모델 URL
    public func downloadModel(_ type: WhisperModelType) async throws -> URL {
        // 네트워크 상태 확인
        guard NetworkMonitor.isNetworkAvailable() else {
            throw WhisperError.networkUnavailable
        }
        
        // 디스크 공간 확인
        try checkDiskSpace(for: type)
        
        // 이미 다운로드 중인 경우 취소
        currentDownloadTask?.cancel()
        
        // 재시도 로직으로 다운로드 시도
        return try await downloadWithRetry(type)
    }
    
    /// 재시도 로직이 포함된 다운로드
    private func downloadWithRetry(_ type: WhisperModelType, attempt: Int = 1) async throws -> URL {
        do {
            return try await performDownload(type)
        } catch {
            if attempt < maxRetryAttempts {
                // 재시도 전 대기
                try await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                
                // 네트워크 상태 재확인
                guard NetworkMonitor.isNetworkAvailable() else {
                    throw WhisperError.networkUnavailable
                }
                
                // 상태 업데이트
                downloadStateSubject.send(.downloading(DetailedModelDownloadProgress(
                    progress: 0,
                    downloadedBytes: 0,
                    totalBytes: 0,
                    downloadSpeed: 0,
                    estimatedTimeRemaining: 0,
                    statusMessage: "재시도 중... (시도 \(attempt + 1)/\(maxRetryAttempts))"
                )))
                
                // 재시도
                return try await downloadWithRetry(type, attempt: attempt + 1)
            }
            throw error
        }
    }
    
    /// 실제 다운로드 수행
    private func performDownload(_ type: WhisperModelType) async throws -> URL {
        let task = Task<URL, Error> {
            // 다운로드 상태 업데이트
            downloadStateSubject.send(.downloading(DetailedModelDownloadProgress(
                progress: 0,
                downloadedBytes: 0,
                totalBytes: 0,
                downloadSpeed: 0,
                estimatedTimeRemaining: 0,
                statusMessage: "다운로드 준비 중..."
            )))
            
            // GitHub Release URL 생성
            let downloadURL = type.githubReleaseURL
            let zipFilePath = modelsDirectory.appendingPathComponent("\(type.coreMLModelName).zip")
            
            // URLSession 다운로드 작업 생성
            var request = URLRequest(url: downloadURL)
            request.timeoutInterval = 30 // 30초 타임아웃
            
            let (tempURL, response) = try await URLSession.shared.download(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw WhisperError.serverError(0)
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                throw WhisperError.serverError(httpResponse.statusCode)
            }
            
            // 다운로드 완료 후 임시 파일을 목적지로 이동
            try FileManager.default.moveItem(at: tempURL, to: zipFilePath)
            
            // 압축 해제
            return try await extractModel(from: zipFilePath, for: type)
        }
        
        currentDownloadTask = task
        
        do {
            return try await task.value
        } catch {
            downloadStateSubject.send(.failed(error))
            throw error
        }
    }
    
    /// 모델 파일 압축 해제
    private func extractModel(from zipFile: URL, for type: WhisperModelType) async throws -> URL {
        downloadStateSubject.send(.extracting(0))
        
        let modelURL = modelPath(for: type)
        
        #if canImport(Zip)
        // Zip 라이브러리를 사용하여 압축 해제
        try Zip.unzipFile(zipFile, destination: modelsDirectory, overwrite: true, password: nil) { progress in
            self.downloadStateSubject.send(.extracting(progress))
        }
        #else
        // Zip 라이브러리가 없는 경우 기본 압축 해제 방법 사용
        try unzipFileWithoutZipLibrary(zipFile, destination: modelsDirectory)
        #endif
        
        // 압축 파일 삭제
        try FileManager.default.removeItem(at: zipFile)
        
        // 캐시 정보 업데이트
        updateCacheInfo(for: type)
        
        // 캐시 크기 관리
        try manageCacheSize()
        
        // 완료 상태 전송
        downloadStateSubject.send(.completed(modelURL))
        
        return modelURL
    }
    
    /// 디스크 공간 확인
    private func checkDiskSpace(for type: WhisperModelType) throws {
        let availableSpace = availableDiskSpace()
        let requiredSpace = Int64(type.sizeInMB) * 1024 * 1024 * 2 // 압축 해제를 위한 추가 공간
        
        // 최소 필요 공간 확인
        if availableSpace < minimumDiskSpace {
            throw WhisperError.insufficientDiskSpace
        }
        
        // 모델 설치에 필요한 공간 확인
        if availableSpace < requiredSpace {
            // 공간 확보 시도
            try manageCacheSize()
            
            // 공간 확보 후 재확인
            let newAvailableSpace = availableDiskSpace()
            if newAvailableSpace < requiredSpace {
                throw WhisperError.insufficientDiskSpace
            }
        }
    }
    
    /// 캐시 크기 관리 개선
    private func manageCacheSize() throws {
        // 현재 캐시 크기 계산
        let totalSize = cacheInfo.values.reduce(0) { $0 + $1.fileSize }
        
        // 최대 크기를 초과하지 않으면 종료
        if totalSize <= maxCacheSize {
            return
        }
        
        // 삭제할 모델 선택 (LRU + 사용 빈도 고려)
        let sortedModels = cacheInfo.values.sorted { model1, model2 in
            // 점수 계산: 마지막 사용일 + 사용 빈도
            let score1 = model1.lastUsedDate.timeIntervalSinceNow + Double(model1.usageCount)
            let score2 = model2.lastUsedDate.timeIntervalSinceNow + Double(model2.usageCount)
            return score1 < score2
        }
        
        var currentSize = totalSize
        for model in sortedModels {
            // tiny 모델은 삭제하지 않음
            if model.modelType == .tiny {
                continue
            }
            
            let modelURL = modelPath(for: model.modelType)
            
            do {
                // 파일 삭제
                try FileManager.default.removeItem(at: modelURL)
                
                // 캐시 정보에서 제거
                cacheInfo.removeValue(forKey: model.modelType.rawValue)
                
                // 크기 업데이트
                currentSize -= model.fileSize
                
                // 목표 크기에 도달하면 종료
                if currentSize <= Int64(Double(maxCacheSize) * 0.8) {
                    break
                }
            } catch {
                print("모델 삭제 실패: \(error)")
                continue
            }
        }
        
        // 캐시 정보 저장
        saveCacheInfo()
    }
    
    /// 캐시 정보 업데이트
    /// - Parameter type: 모델 타입
    private func updateCacheInfo(for type: WhisperModelType) {
        let modelURL = modelPath(for: type)
        
        // 파일 크기 확인
        let fileSize: Int64
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: modelURL.path)
            fileSize = attributes[.size] as? Int64 ?? 0
        } catch {
            fileSize = 0
        }
        
        // 체크섬 계산 (간단한 구현)
        let checksum = "checksum-placeholder"
        
        // 기존 캐시 정보 확인
        if var info = cacheInfo[type.rawValue] {
            // 기존 정보 업데이트
            info.lastUsedDate = Date()
            info.usageCount += 1
            cacheInfo[type.rawValue] = info
        } else {
            // 새 캐시 정보 생성
            let info = ModelCacheInfo(
                modelType: type,
                downloadDate: Date(),
                lastUsedDate: Date(),
                usageCount: 1,
                fileSize: fileSize,
                version: "1.0",
                checksum: checksum
            )
            cacheInfo[type.rawValue] = info
        }
        
        // 캐시 정보 저장
        saveCacheInfo()
    }
    
    /// 모델 삭제
    /// - Parameter type: 모델 타입
    public func deleteModel(_ type: WhisperModelType) throws {
        // tiny 모델은 삭제 불가 (기본 모델)
        if type == .tiny {
            throw NSError(domain: "ModelManager", code: 400, userInfo: [
                NSLocalizedDescriptionKey: "기본 모델은 삭제할 수 없습니다."
            ])
        }
        
        let modelURL = modelPath(for: type)
        
        // 파일 존재 여부 확인
        guard FileManager.default.fileExists(atPath: modelURL.path) else {
            return
        }
        
        // 파일 삭제
        try FileManager.default.removeItem(at: modelURL)
        
        // 캐시 정보에서 제거
        cacheInfo.removeValue(forKey: type.rawValue)
        
        // 캐시 정보 저장
        saveCacheInfo()
    }
    
    /// 모델 존재 여부 확인
    /// - Parameter type: 모델 타입
    /// - Returns: 존재 여부
    public func modelExists(_ type: WhisperModelType) -> Bool {
        let modelURL = modelPath(for: type)
        return FileManager.default.fileExists(atPath: modelURL.path)
    }
    
    /// 모든 캐시 정보 조회
    /// - Returns: 캐시 정보 배열
    public func getAllCacheInfo() -> [ModelCacheInfo] {
        Array(cacheInfo.values)
    }
    
    /// 모든 캐시 삭제
    public func clearAllCache() throws {
        // tiny 모델 정보 저장
        let tinyInfo = cacheInfo[WhisperModelType.tiny.rawValue]
        
        // 모든 파일 삭제
        for model in cacheInfo.values {
            // tiny 모델은 삭제하지 않음
            if model.modelType == .tiny {
                continue
            }
            
            let modelURL = modelPath(for: model.modelType)
            try? FileManager.default.removeItem(at: modelURL)
        }
        
        // 캐시 정보 초기화
        cacheInfo.removeAll()
        
        // tiny 모델 정보 복원
        if let tinyInfo = tinyInfo {
            cacheInfo[WhisperModelType.tiny.rawValue] = tinyInfo
        }
        
        // 캐시 정보 저장
        saveCacheInfo()
    }
    
    /// 사용 가능한 디스크 공간 확인
    /// - Returns: 사용 가능한 공간 (바이트)
    public func availableDiskSpace() -> Int64 {
        do {
            let attributes = try FileManager.default.attributesOfFileSystem(forPath: modelsDirectory.path)
            return attributes[.systemFreeSize] as? Int64 ?? 0
        } catch {
            return 0
        }
    }
    
    /// 모델 다운로드 전 공간 확인
    /// - Parameter type: 모델 타입
    /// - Returns: 다운로드 가능 여부
    public func canDownloadModel(_ type: WhisperModelType) -> Bool {
        let availableSpace = availableDiskSpace()
        let requiredSpace = Int64(type.sizeInMB) * 1024 * 1024 * 2 // 압축 해제를 위한 추가 공간
        
        return availableSpace >= requiredSpace
    }
    
    #if !canImport(Zip)
    /// Zip 라이브러리 없이 압축 해제 (기본 구현)
    private func unzipFileWithoutZipLibrary(_ zipFile: URL, destination: URL) throws {
        // 기본 압축 해제 로직 (예: Process 사용)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-o", zipFile.path, "-d", destination.path]
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            throw NSError(domain: "ModelManager", code: Int(process.terminationStatus), userInfo: [
                NSLocalizedDescriptionKey: "압축 해제 실패: \(process.terminationStatus)"
            ])
        }
    }
    #endif
} 