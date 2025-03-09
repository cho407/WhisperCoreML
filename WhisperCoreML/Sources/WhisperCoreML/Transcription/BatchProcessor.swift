import Foundation
import CoreML

/// 배치 처리 상태
public struct BatchProcessingStatus {
    public let totalFiles: Int
    public let processedFiles: Int
    public let currentFile: String
    public let progress: Double
    public let estimatedTimeRemaining: TimeInterval?
    public let processingSpeed: Double?  // 초당 처리된 파일 수
    public let currentFileProgress: Double?  // 현재 파일의 처리 진행률
    public let errorCount: Int  // 처리 중 발생한 오류 수
    
    internal init(
        totalFiles: Int,
        processedFiles: Int,
        currentFile: String,
        progress: Double,
        estimatedTimeRemaining: TimeInterval? = nil,
        processingSpeed: Double? = nil,
        currentFileProgress: Double? = nil,
        errorCount: Int = 0
    ) {
        self.totalFiles = totalFiles
        self.processedFiles = processedFiles
        self.currentFile = currentFile
        self.progress = progress
        self.estimatedTimeRemaining = estimatedTimeRemaining
        self.processingSpeed = processingSpeed
        self.currentFileProgress = currentFileProgress
        self.errorCount = errorCount
    }
}

/// 배치 처리 결과
public struct BatchProcessingResult {
    public let fileURL: URL
    public let transcription: String
    public let language: String?
    public let duration: TimeInterval
    public let error: Error?
    public let processingTime: TimeInterval  // 처리에 소요된 시간
    public let fileSize: Int64  // 파일 크기 (바이트)
    
    internal init(
        fileURL: URL,
        transcription: String,
        language: String?,
        duration: TimeInterval,
        error: Error?,
        processingTime: TimeInterval,
        fileSize: Int64
    ) {
        self.fileURL = fileURL
        self.transcription = transcription
        self.language = language
        self.duration = duration
        self.error = error
        self.processingTime = processingTime
        self.fileSize = fileSize
    }
}

/// 배치 처리기
public actor BatchProcessor {
    private let model: WhisperModel
    private let formatConverter: AudioFormatConverter
    private let maxConcurrentProcessing: Int
    
    // 상태 관리를 위한 구조체
    private struct ProcessingState {
        var totalFiles: Int = 0
        var processedCount: Int = 0
        var processingTimes: [TimeInterval] = []
        var errorCount: Int = 0
        
        mutating func reset() {
            processedCount = 0
            processingTimes.removeAll()
            errorCount = 0
        }
    }
    
    private var state: ProcessingState = ProcessingState()
    
    public init(model: WhisperModel, maxConcurrentProcessing: Int = 2) {
        self.model = model
        self.formatConverter = AudioFormatConverter.shared
        self.maxConcurrentProcessing = maxConcurrentProcessing
    }
    
    /// 여러 파일을 배치로 처리
    /// - Parameters:
    ///   - urls: 처리할 파일 URL 배열
    ///   - progressHandler: 진행 상황을 받을 핸들러
    /// - Returns: 처리 결과 배열
    public func processBatch(
        urls: [URL],
        progressHandler: @escaping @MainActor (BatchProcessingStatus) -> Void
    ) async throws -> [BatchProcessingResult] {
        var results: [BatchProcessingResult] = []
        let startTime = Date()
        
        // 초기 상태 설정
        state.totalFiles = urls.count
        state.reset()
        
        // 배치 크기만큼 작업 생성
        for i in stride(from: 0, to: urls.count, by: maxConcurrentProcessing) {
            let batch = Array(urls[i..<min(i + maxConcurrentProcessing, urls.count)])
            let batchTasks = batch.map { url in
                Task {
                    do {
                        let fileSize = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64 ?? 0
                        let taskStartTime = Date()
                        
                        // 오디오 변환
                        let wavURL = try await formatConverter.convertToWAV(url)
                        
                        // 음성 인식
                        let result = try await model.transcribe(
                            audioURL: wavURL,
                            options: .default
                        ) { [weak self] progress in
                            Task { [self] in
                                if let self {
                                    await self.updateProgressStatus(
                                        progress: progress,
                                        currentFile: url.lastPathComponent,
                                        startTime: startTime,
                                        progressHandler: progressHandler
                                    )
                                }
                            }
                        }
                        
                        let transcription = result.segments.map { $0.text }.joined(separator: " ")
                        let language = result.detectedLanguage
                        let processingTime = Date().timeIntervalSince(taskStartTime)
                        
                        // 상태 업데이트
                        await self.updateProcessingState(processingTime: processingTime)
                        
                        // 최종 진행 상황 업데이트
                        await self.updateProgressStatus(
                            progress: 1.0,
                            currentFile: url.lastPathComponent,
                            startTime: startTime,
                            progressHandler: progressHandler
                        )
                        
                        return BatchProcessingResult(
                            fileURL: url,
                            transcription: transcription,
                            language: language,
                            duration: result.segments.last?.end ?? 0,
                            error: nil,
                            processingTime: processingTime,
                            fileSize: fileSize
                        )
                    } catch {
                        await self.incrementErrorCount()
                        return BatchProcessingResult(
                            fileURL: url,
                            transcription: "",
                            language: nil,
                            duration: 0,
                            error: error,
                            processingTime: 0,
                            fileSize: 0
                        )
                    }
                }
            }
            
            // 현재 배치 처리 완료 대기
            for task in batchTasks {
                let result = await task.value
                results.append(result)
            }
        }
        
        return results
    }
    
    // MARK: - Private Methods
    
    private func updateProcessingState(processingTime: TimeInterval) async {
        state.processingTimes.append(processingTime)
        state.processedCount += 1
    }
    
    private func incrementErrorCount() async {
        state.errorCount += 1
    }
    
    private func updateProgressStatus(
        progress: Double,
        currentFile: String,
        startTime: Date,
        progressHandler: @MainActor (BatchProcessingStatus) -> Void
    ) async {
        let currentState = state
        let overallProgress = (Double(currentState.processedCount) + progress) / Double(currentState.totalFiles)
        let timeElapsed = Date().timeIntervalSince(startTime)
        
        // 예상 시간 계산
        let estimatedTotal = timeElapsed / (overallProgress > 0 ? overallProgress : 1)
        let estimatedRemaining = estimatedTotal - timeElapsed
        
        // 처리 속도 계산
        let averageProcessingTime = currentState.processingTimes.isEmpty ? 0 :
            currentState.processingTimes.reduce(0, +) / Double(currentState.processingTimes.count)
        let processingSpeed = averageProcessingTime > 0 ? 1.0 / averageProcessingTime : 0
        
        let status = BatchProcessingStatus(
            totalFiles: currentState.totalFiles,
            processedFiles: currentState.processedCount,
            currentFile: currentFile,
            progress: overallProgress,
            estimatedTimeRemaining: estimatedRemaining,
            processingSpeed: processingSpeed,
            currentFileProgress: progress,
            errorCount: currentState.errorCount
        )
        
        await MainActor.run {
            progressHandler(status)
        }
    }
    
    /// 처리 취소
    public func cancelProcessing() async {
        state.reset()
    }
    
    /// 처리 통계 초기화
    public func resetStatistics() async {
        state.reset()
    }
} 
