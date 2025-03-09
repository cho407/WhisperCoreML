import Foundation

/// 모델 메타데이터
public struct ModelMetadata: Codable, Equatable {
    /// 모델 타입
    public let modelType: WhisperModelType
    
    /// 모델 버전
    public let version: String
    
    /// 릴리스 날짜
    public let releaseDate: Date
    
    /// 마지막 사용 날짜
    public var lastUsedDate: Date
    
    /// 사용 횟수
    public var usageCount: Int
    
    /// 평균 처리 시간 (초)
    public var averageProcessingTime: TimeInterval
    
    /// 모델 파일 크기 (바이트)
    public let fileSize: Int64
    
    /// 지원하는 언어 목록
    public let supportedLanguages: [String]
    
    /// 모델 성능 지표
    public let performanceMetrics: PerformanceMetrics
    
    /// 모델 파일 경로
    public let filePath: String
    
    /// 모델 다운로드 URL
    public let downloadURL: URL?
    
    /// 모델 체크섬 (SHA-256)
    public let checksum: String?
    
    /// 추가 정보
    public var additionalInfo: [String: String]
    
    /// 초기화 메서드
    public init(
        modelType: WhisperModelType,
        version: String,
        releaseDate: Date,
        lastUsedDate: Date = Date(),
        usageCount: Int = 0,
        averageProcessingTime: TimeInterval = 0,
        fileSize: Int64,
        supportedLanguages: [String],
        performanceMetrics: PerformanceMetrics,
        filePath: String,
        downloadURL: URL? = nil,
        checksum: String? = nil,
        additionalInfo: [String: String] = [:]
    ) {
        self.modelType = modelType
        self.version = version
        self.releaseDate = releaseDate
        self.lastUsedDate = lastUsedDate
        self.usageCount = usageCount
        self.averageProcessingTime = averageProcessingTime
        self.fileSize = fileSize
        self.supportedLanguages = supportedLanguages
        self.performanceMetrics = performanceMetrics
        self.filePath = filePath
        self.downloadURL = downloadURL
        self.checksum = checksum
        self.additionalInfo = additionalInfo
    }
    
    // Codable 구현을 위한 CodingKeys
    private enum CodingKeys: String, CodingKey {
        case modelType, version, releaseDate, lastUsedDate, usageCount
        case averageProcessingTime, fileSize, supportedLanguages
        case performanceMetrics, filePath, downloadURL, checksum, additionalInfo
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
        
        version = try container.decode(String.self, forKey: .version)
        releaseDate = try container.decode(Date.self, forKey: .releaseDate)
        lastUsedDate = try container.decode(Date.self, forKey: .lastUsedDate)
        usageCount = try container.decode(Int.self, forKey: .usageCount)
        averageProcessingTime = try container.decode(TimeInterval.self, forKey: .averageProcessingTime)
        fileSize = try container.decode(Int64.self, forKey: .fileSize)
        supportedLanguages = try container.decode([String].self, forKey: .supportedLanguages)
        performanceMetrics = try container.decode(PerformanceMetrics.self, forKey: .performanceMetrics)
        filePath = try container.decode(String.self, forKey: .filePath)
        downloadURL = try container.decodeIfPresent(URL.self, forKey: .downloadURL)
        checksum = try container.decodeIfPresent(String.self, forKey: .checksum)
        additionalInfo = try container.decode([String: String].self, forKey: .additionalInfo)
    }
    
    // Encodable 구현
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(modelType.rawValue, forKey: .modelType)
        try container.encode(version, forKey: .version)
        try container.encode(releaseDate, forKey: .releaseDate)
        try container.encode(lastUsedDate, forKey: .lastUsedDate)
        try container.encode(usageCount, forKey: .usageCount)
        try container.encode(averageProcessingTime, forKey: .averageProcessingTime)
        try container.encode(fileSize, forKey: .fileSize)
        try container.encode(supportedLanguages, forKey: .supportedLanguages)
        try container.encode(performanceMetrics, forKey: .performanceMetrics)
        try container.encode(filePath, forKey: .filePath)
        try container.encodeIfPresent(downloadURL, forKey: .downloadURL)
        try container.encodeIfPresent(checksum, forKey: .checksum)
        try container.encode(additionalInfo, forKey: .additionalInfo)
    }
    
    /// 모델 사용 기록 업데이트
    public mutating func recordUsage(processingTime: TimeInterval) {
        let totalTime = averageProcessingTime * Double(usageCount)
        usageCount += 1
        lastUsedDate = Date()
        averageProcessingTime = (totalTime + processingTime) / Double(usageCount)
    }
    
    /// 사전 표현으로 변환
    public func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "model_type": modelType.rawValue,
            "version": version,
            "release_date": releaseDate.timeIntervalSince1970,
            "last_used_date": lastUsedDate.timeIntervalSince1970,
            "usage_count": usageCount,
            "average_processing_time": averageProcessingTime,
            "file_size": fileSize,
            "supported_languages": supportedLanguages,
            "performance_metrics": performanceMetrics.toDictionary(),
            "file_path": filePath
        ]
        
        if let downloadURL = downloadURL {
            dict["download_url"] = downloadURL.absoluteString
        }
        
        if let checksum = checksum {
            dict["checksum"] = checksum
        }
        
        dict["additional_info"] = additionalInfo
        
        return dict
    }
    
    /// 사전에서 생성
    public static func fromDictionary(_ dict: [String: Any]) -> ModelMetadata? {
        guard let modelTypeString = dict["model_type"] as? String,
              let modelType = WhisperModelType(rawValue: modelTypeString),
              let version = dict["version"] as? String,
              let releaseDateTimestamp = dict["release_date"] as? TimeInterval,
              let lastUsedDateTimestamp = dict["last_used_date"] as? TimeInterval,
              let usageCount = dict["usage_count"] as? Int,
              let averageProcessingTime = dict["average_processing_time"] as? TimeInterval,
              let fileSize = dict["file_size"] as? Int64,
              let supportedLanguages = dict["supported_languages"] as? [String],
              let performanceMetricsDict = dict["performance_metrics"] as? [String: Any],
              let filePath = dict["file_path"] as? String else {
            return nil
        }
        
        guard let performanceMetrics = PerformanceMetrics.fromDictionary(performanceMetricsDict) else {
            return nil
        }
        
        let releaseDate = Date(timeIntervalSince1970: releaseDateTimestamp)
        let lastUsedDate = Date(timeIntervalSince1970: lastUsedDateTimestamp)
        
        var downloadURL: URL? = nil
        if let downloadURLString = dict["download_url"] as? String {
            downloadURL = URL(string: downloadURLString)
        }
        
        let checksum = dict["checksum"] as? String
        let additionalInfo = dict["additional_info"] as? [String: String] ?? [:]
        
        return ModelMetadata(
            modelType: modelType,
            version: version,
            releaseDate: releaseDate,
            lastUsedDate: lastUsedDate,
            usageCount: usageCount,
            averageProcessingTime: averageProcessingTime,
            fileSize: fileSize,
            supportedLanguages: supportedLanguages,
            performanceMetrics: performanceMetrics,
            filePath: filePath,
            downloadURL: downloadURL,
            checksum: checksum,
            additionalInfo: additionalInfo
        )
    }
}

/// 모델 성능 지표
public struct PerformanceMetrics: Codable, Equatable {
    /// 정확도 (0.0 ~ 1.0)
    public let accuracy: Float
    
    /// 평균 처리 속도 (초당 오디오 길이)
    public let processingSpeed: Float
    
    /// 메모리 사용량 (MB)
    public let memoryUsage: Float
    
    /// 초기화 메서드
    public init(
        accuracy: Float,
        processingSpeed: Float,
        memoryUsage: Float
    ) {
        self.accuracy = accuracy
        self.processingSpeed = processingSpeed
        self.memoryUsage = memoryUsage
    }
    
    /// 사전 표현으로 변환
    public func toDictionary() -> [String: Any] {
        return [
            "accuracy": accuracy,
            "processing_speed": processingSpeed,
            "memory_usage": memoryUsage
        ]
    }
    
    /// 사전에서 생성
    public static func fromDictionary(_ dict: [String: Any]) -> PerformanceMetrics? {
        guard let accuracy = dict["accuracy"] as? Float,
              let processingSpeed = dict["processing_speed"] as? Float,
              let memoryUsage = dict["memory_usage"] as? Float else {
            return nil
        }
        
        return PerformanceMetrics(
            accuracy: accuracy,
            processingSpeed: processingSpeed,
            memoryUsage: memoryUsage
        )
    }
}

/// 모델 메타데이터 관리자
public class ModelMetadataManager {
    /// 싱글톤 인스턴스
    public static let shared = ModelMetadataManager()
    
    /// 메타데이터 저장소
    private var metadataStore: [String: ModelMetadata] = [:]
    
    /// 메타데이터 파일 URL
    private let metadataFileURL: URL
    
    /// 초기화
    private init() {
        let fileManager = FileManager.default
        let appSupportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let whisperDirectory = appSupportDirectory.appendingPathComponent("WhisperModels", isDirectory: true)
        
        // 디렉토리 생성
        try? fileManager.createDirectory(at: whisperDirectory, withIntermediateDirectories: true)
        
        self.metadataFileURL = whisperDirectory.appendingPathComponent("metadata.json")
        
        // 저장된 메타데이터 로드
        loadMetadata()
    }
    
    /// 메타데이터 로드
    private func loadMetadata() {
        do {
            let data = try Data(contentsOf: metadataFileURL)
            let jsonObject = try JSONSerialization.jsonObject(with: data)
            
            guard let metadataDict = jsonObject as? [String: [String: Any]] else {
                ErrorLogger.log("메타데이터 형식이 올바르지 않습니다.", level: .warning)
                return
            }
            
            for (key, value) in metadataDict {
                if let metadata = ModelMetadata.fromDictionary(value) {
                    metadataStore[key] = metadata
                }
            }
            
            ErrorLogger.log("메타데이터 로드 성공: \(metadataStore.count)개 모델", level: .info)
        } catch {
            ErrorLogger.log("메타데이터 로드 실패: \(error.localizedDescription)", level: .warning)
        }
    }
    
    /// 메타데이터 저장
    private func saveMetadata() {
        do {
            var metadataDict: [String: Any] = [:]
            
            for (key, metadata) in metadataStore {
                metadataDict[key] = metadata.toDictionary()
            }
            
            let data = try JSONSerialization.data(withJSONObject: metadataDict, options: [.prettyPrinted])
            try data.write(to: metadataFileURL)
            
            ErrorLogger.log("메타데이터 저장 성공", level: .info)
        } catch {
            ErrorLogger.log("메타데이터 저장 실패: \(error.localizedDescription)", level: .error)
        }
    }
    
    /// 모델 메타데이터 가져오기
    /// - Parameter modelType: 모델 타입
    /// - Returns: 모델 메타데이터 (없으면 nil)
    public func getMetadata(for modelType: WhisperModelType) -> ModelMetadata? {
        return metadataStore[modelType.rawValue]
    }
    
    /// 모델 메타데이터 설정
    /// - Parameters:
    ///   - metadata: 모델 메타데이터
    ///   - modelType: 모델 타입
    public func setMetadata(_ metadata: ModelMetadata, for modelType: WhisperModelType) {
        metadataStore[modelType.rawValue] = metadata
        saveMetadata()
    }
    
    /// 모델 사용 기록
    /// - Parameters:
    ///   - modelType: 모델 타입
    ///   - processingTime: 처리 시간
    public func recordModelUsage(modelType: WhisperModelType, processingTime: TimeInterval) {
        if var metadata = metadataStore[modelType.rawValue] {
            metadata.recordUsage(processingTime: processingTime)
            metadataStore[modelType.rawValue] = metadata
            saveMetadata()
        }
    }
    
    /// 모든 모델 메타데이터 가져오기
    /// - Returns: 모든 모델 메타데이터 배열
    public func getAllMetadata() -> [ModelMetadata] {
        return Array(metadataStore.values)
    }
    
    /// 모델 메타데이터 삭제
    /// - Parameter modelType: 모델 타입
    public func removeMetadata(for modelType: WhisperModelType) {
        metadataStore.removeValue(forKey: modelType.rawValue)
        saveMetadata()
    }
    
    /// 기본 메타데이터 생성
    /// - Parameter modelType: 모델 타입
    /// - Returns: 기본 메타데이터
    public func createDefaultMetadata(for modelType: WhisperModelType) -> ModelMetadata {
        let fileManager = FileManager.default
        let appSupportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let modelDirectory = appSupportDirectory.appendingPathComponent("WhisperModels", isDirectory: true)
        let modelPath = modelDirectory.appendingPathComponent("\(modelType.rawValue).mlmodelc").path
        
        // 파일 크기 확인
        var fileSize: Int64 = 0
        do {
            let attributes = try fileManager.attributesOfItem(atPath: modelPath)
            fileSize = attributes[.size] as? Int64 ?? 0
        } catch {
            ErrorLogger.log("파일 크기 확인 실패: \(error.localizedDescription)", level: .warning)
        }
        
        // 지원하는 언어 목록
        let supportedLanguages = getSupportedLanguages(for: modelType)
        
        // 성능 지표
        let performanceMetrics = getDefaultPerformanceMetrics(for: modelType)
        
        return ModelMetadata(
            modelType: modelType,
            version: "1.0.0",
            releaseDate: Date(),
            fileSize: fileSize,
            supportedLanguages: supportedLanguages,
            performanceMetrics: performanceMetrics,
            filePath: modelPath,
            downloadURL: modelType.downloadURL
        )
    }
    
    /// 모델 타입에 따른 지원 언어 목록
    private func getSupportedLanguages(for modelType: WhisperModelType) -> [String] {
        // 모든 모델이 지원하는 기본 언어
        let baseLanguages = ["en", "es", "fr", "de", "it", "pt", "nl", "ja", "zh", "ko"]
        
        // 확장된 언어 목록 (중간 크기 이상 모델)
        let extendedLanguages = baseLanguages + ["ru", "pl", "tr", "ar", "hi", "uk", "vi", "cs", "da", "fi", "el", "hu", "id", "no", "ro", "sk", "sv", "th"]
        
        // 모든 언어 목록 (large 모델)
        let allLanguages = extendedLanguages + ["bg", "ca", "hr", "et", "he", "lv", "lt", "mk", "sr", "sl", "ta", "te", "ur"]
        
        // 모델 크기에 따라 지원하는 언어 확장
        switch modelType {
        case .tiny:
            return baseLanguages
        case .base:
            return baseLanguages + ["ru", "pl", "tr"]
        case .small:
            return extendedLanguages
        case .medium:
            return extendedLanguages
        case .large:
            return allLanguages
        case .largeV2:
            return allLanguages
        case .largeV3:
            return allLanguages
        @unknown default:
            return baseLanguages
        }
    }
    
    /// 모델 타입에 따른 기본 성능 지표
    private func getDefaultPerformanceMetrics(for modelType: WhisperModelType) -> PerformanceMetrics {
        switch modelType {
        case .tiny:
            return PerformanceMetrics(accuracy: 0.65, processingSpeed: 3.0, memoryUsage: 150)
        case .base:
            return PerformanceMetrics(accuracy: 0.75, processingSpeed: 2.5, memoryUsage: 300)
        case .small:
            return PerformanceMetrics(accuracy: 0.82, processingSpeed: 1.8, memoryUsage: 600)
        case .medium:
            return PerformanceMetrics(accuracy: 0.88, processingSpeed: 1.2, memoryUsage: 1200)
        case .large:
            return PerformanceMetrics(accuracy: 0.93, processingSpeed: 0.8, memoryUsage: 2400)
        case .largeV2:
            return PerformanceMetrics(accuracy: 0.95, processingSpeed: 0.7, memoryUsage: 2600)
        case .largeV3:
            return PerformanceMetrics(accuracy: 0.96, processingSpeed: 0.6, memoryUsage: 2800)
        @unknown default:
            return PerformanceMetrics(accuracy: 0.75, processingSpeed: 2.0, memoryUsage: 500)
        }
    }
} 