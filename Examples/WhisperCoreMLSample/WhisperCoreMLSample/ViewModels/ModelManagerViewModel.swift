import Foundation
import Combine
import WhisperCoreML

/// 모델 관리 기능을 담당하는 ViewModel
class ModelManagerViewModel: ObservableObject {
    // MARK: - 속성
    
    private let transcriptionService = TranscriptionService()
    
    @Published var modelInfos: [ModelInfo] = []
    @Published var downloadingModelInfo: ModelInfo?
    @Published var downloadProgress: Double = 0
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - 초기화
    
    init() {
        loadModels()
    }
    
    // MARK: - 모델 관리
    
    /// 사용 가능한 모델 로드
    func loadModels() {
        modelInfos = transcriptionService.availableModels
    }
    
    /// 모델 다운로드
    /// - Parameter modelType: 다운로드할 모델 타입
    func downloadModel(_ modelType: WhisperModelType) {
        // 이미 다운로드 중인 경우 무시
        guard downloadingModelInfo == nil else { return }
        
        // 이미 다운로드된 경우 무시
        guard !modelType.allRequiredFilesExist() else { return }
        
        // 다운로드할 모델 정보 설정
        let modelInfo = modelInfos.first { $0.type == modelType }!
        downloadingModelInfo = ModelInfo(
            type: modelType,
            isDownloaded: false,
            downloadProgress: 0.0,
            isBuiltIn: modelInfo.isBuiltIn
        )
        
        // 다운로드 시작
        transcriptionService.downloadModel(modelType: modelType)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self = self else { return }
                    
                    switch completion {
                    case .finished:
                        // 다운로드 완료
                        self.downloadingModelInfo = nil
                        self.transcriptionService.loadAvailableModels()
                        self.loadModels()
                    case .failure(let error):
                        // 다운로드 실패
                        print("모델 다운로드 실패: \(error.localizedDescription)")
                        self.downloadingModelInfo = nil
                    }
                },
                receiveValue: { [weak self] progress in
                    guard let self = self else { return }
                    
                    // 진행 상황 업데이트
                    self.downloadProgress = progress
                    self.downloadingModelInfo = ModelInfo(
                        type: modelType,
                        isDownloaded: false,
                        downloadProgress: progress,
                        isBuiltIn: modelInfo.isBuiltIn
                    )
                }
            )
            .store(in: &cancellables)
    }
    
    /// 모델 삭제
    /// - Parameter modelType: 삭제할 모델 타입
    func deleteModel(_ modelType: WhisperModelType) {
        // 내장 모델은 삭제할 수 없음
        guard modelType != .tiny else { return }
        
        // 파일 시스템에서 모델 파일 삭제
        let fileManager = FileManager.default
        let appSupportURL = try! fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let modelDirectory = appSupportURL.appendingPathComponent("WhisperCoreML/Models/\(modelType.rawValue)", isDirectory: true)
        
        do {
            if fileManager.fileExists(atPath: modelDirectory.path) {
                try fileManager.removeItem(at: modelDirectory)
            }
            
            // 모델 목록 갱신
            transcriptionService.loadAvailableModels()
            loadModels()
        } catch {
            print("모델 삭제 실패: \(error.localizedDescription)")
        }
    }
    
    /// 현재 선택된 모델 설정
    /// - Parameter modelType: 선택할 모델 타입
    func setCurrentModel(_ modelType: WhisperModelType) {
        transcriptionService.currentModel = modelType
    }
    
    /// 모델이 다운로드 가능한지 확인
    /// - Parameter modelType: 확인할 모델 타입
    /// - Returns: 다운로드 가능 여부
    func canDownloadModel(_ modelType: WhisperModelType) -> Bool {
        // 이미 다운로드된 모델이거나 다운로드 중인 모델은 다운로드 불가
        let isDownloaded = modelType.allRequiredFilesExist()
        let isDownloading = downloadingModelInfo?.type == modelType
        
        return !isDownloaded && !isDownloading
    }
    
    /// 모델 다운로드 취소
    func cancelDownload() {
        cancellables.forEach { $0.cancel() }
        downloadingModelInfo = nil
    }
    
    /// 모델 사용량 정보 계산
    /// - Returns: 전체 사용 공간 및 각 모델별 사용 공간
    func calculateStorageUsage() -> (total: Int64, breakdown: [String: Int64]) {
        var totalSize: Int64 = 0
        var breakdown: [String: Int64] = [:]
        
        let fileManager = FileManager.default
        let appSupportURL = try! fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let modelsDirectory = appSupportURL.appendingPathComponent("WhisperCoreML/Models", isDirectory: true)
        
        // 모델 디렉토리가 없으면 0 반환
        guard fileManager.fileExists(atPath: modelsDirectory.path) else {
            return (0, [:])
        }
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: modelsDirectory, includingPropertiesForKeys: nil)
            
            for modelDir in contents {
                guard modelDir.hasDirectoryPath else { continue }
                
                let modelName = modelDir.lastPathComponent
                let modelSize = try calculateDirectorySize(at: modelDir)
                
                breakdown[modelName] = modelSize
                totalSize += modelSize
            }
        } catch {
            print("스토리지 사용량 계산 실패: \(error.localizedDescription)")
        }
        
        return (totalSize, breakdown)
    }
    
    /// 디렉토리 크기 계산 유틸리티
    /// - Parameter url: 크기를 계산할 디렉토리 URL
    /// - Returns: 디렉토리 크기 (바이트)
    private func calculateDirectorySize(at url: URL) throws -> Int64 {
        let fileManager = FileManager.default
        let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.fileSizeKey])
        
        var size: Int64 = 0
        
        for fileURL in contents {
            let resourceValues = try fileURL.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
            
            if resourceValues.isDirectory ?? false {
                size += try calculateDirectorySize(at: fileURL)
            } else {
                size += Int64(resourceValues.fileSize ?? 0)
            }
        }
        
        return size
    }
} 