import Foundation
import Combine
import WhisperCoreML
import AVFAudio

/// WhisperCoreML을 사용하여 음성 인식을 수행하는 서비스 클래스
class TranscriptionService: ObservableObject {
    // MARK: - 속성
    
    @Published var isProcessing = false
    @Published var progressValue: Double = 0
    @Published var currentModel: WhisperModelType = .tiny
    @Published var availableModels: [ModelInfo] = []
    
    private var bridgeManager = BridgeManager.shared
    private var modelBridge: ModelBridge {
        bridgeManager.modelBridge
    }
    
    private var modelTypeBridge: ModelTypeBridge {
        bridgeManager.modelTypeBridge
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - 초기화
    
    init() {
        loadAvailableModels()
    }
    
    // MARK: - 모델 관리
    
    func loadAvailableModels() {
        availableModels = WhisperModelType.allCases.map { type in
            let isDownloaded = type.allRequiredFilesExist()
            let isBuiltIn = type == .tiny
            
            return ModelInfo(
                type: type,
                isDownloaded: isDownloaded,
                downloadProgress: nil,
                isBuiltIn: isBuiltIn
            )
        }
    }
    
    /// 모델 다운로드
    /// - Parameter modelType: 다운로드할 모델 타입
    /// - Returns: 다운로드 진행 상황 및 결과를 포함하는 Publisher
    func downloadModel(modelType: WhisperModelType) -> AnyPublisher<Double, Error> {
        // 이미 다운로드된 모델이면 완료 처리
        if modelType.allRequiredFilesExist() {
            return Just(1.0)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
        
        // 진행 상황을 보고하는 PassthroughSubject
        let progressSubject = PassthroughSubject<Double, Error>()
        
        // 모델 다운로드 시작
        Task {
            do {
                // 인코더 모델 다운로드
                if !modelType.encoderModelExists() {
                    let encoderURL = modelType.encoderModelURL
                    try await downloadFile(from: encoderURL, progressHandler: { progress in
                        // 인코더는 전체 작업의 40%
                        Task { @MainActor in
                            progressSubject.send(progress * 0.4)
                        }
                    })
                } else {
                    // 이미 존재하면 40% 진행 처리
                    progressSubject.send(0.4)
                }
                
                // 디코더 모델 다운로드
                if !modelType.decoderModelExists() {
                    let decoderURL = modelType.decoderModelURL
                    try await downloadFile(from: decoderURL, progressHandler: { progress in
                        // 디코더는 전체 작업의 40%
                        Task { @MainActor in
                            progressSubject.send(0.4 + progress * 0.4)
                        }
                    })
                } else {
                    // 이미 존재하면 80% 진행 처리
                    progressSubject.send(0.8)
                }
                
                // 구성 파일 다운로드
                if !modelType.configFileExists() {
                    let configURL = modelType.configFileURL
                    try await downloadFile(from: configURL, progressHandler: { progress in
                        // 구성 파일은 전체 작업의 20%
                        Task { @MainActor in
                            progressSubject.send(0.8 + progress * 0.2)
                        }
                    })
                }
                
                // 다운로드 완료, 모델 목록 갱신
                Task { @MainActor in
                    progressSubject.send(1.0)
                    progressSubject.send(completion: .finished)
                    loadAvailableModels()
                }
            } catch {
                Task { @MainActor in
                    progressSubject.send(completion: .failure(error))
                }
            }
        }
        
        return progressSubject.eraseToAnyPublisher()
    }
    
    /// 파일 다운로드 유틸리티 함수
    /// - Parameters:
    ///   - url: 다운로드할 파일 URL
    ///   - progressHandler: 진행 상황 핸들러 (0.0 ~ 1.0)
    private func downloadFile(from url: URL, progressHandler: @escaping (Double) -> Void) async throws {
        // URL 세션 구성
        let configuration = URLSessionConfiguration.default
        let session = URLSession(configuration: configuration)
        
        // 다운로드 작업 생성
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        // 임시 저장 경로
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let tempURL = documentsURL.appendingPathComponent(url.lastPathComponent)
        
        // 다운로드 작업 수행
        let (downloadURL, response) = try await session.download(for: request, delegate: ProgressDelegate(progressHandler: progressHandler))
        
        // HTTP 응답 확인
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        // 파일 저장 경로 생성
        let pathComponents = url.pathComponents
        let modelTypeName = pathComponents[pathComponents.count - 2].lowercased()
        
        let fileManager = FileManager.default
        let appSupportURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let modelDirectory = appSupportURL.appendingPathComponent("WhisperCoreML/Models/\(modelTypeName)", isDirectory: true)
        
        // 디렉토리가 없으면 생성
        if !fileManager.fileExists(atPath: modelDirectory.path) {
            try fileManager.createDirectory(at: modelDirectory, withIntermediateDirectories: true, attributes: nil)
        }
        
        // 최종 저장 경로
        let destinationURL = modelDirectory.appendingPathComponent(url.lastPathComponent)
        
        // 이미 파일이 존재하면 삭제
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        
        // 다운로드한 파일 이동
        try fileManager.moveItem(at: downloadURL, to: destinationURL)
    }
    
    // MARK: - 음성 인식
    
    /// 음성 파일 트랜스크립션 수행
    /// - Parameters:
    ///   - audioFileURL: 오디오 파일 URL
    ///   - language: 언어 코드 (자동 감지면 nil)
    /// - Returns: 음성 인식 결과
    func transcribeAudioFile(at audioFileURL: URL, language: String? = nil) async throws -> TranscriptionResult {
        isProcessing = true
        progressValue = 0
        
        defer {
            Task { @MainActor in
                self.isProcessing = false
                self.progressValue = 0
            }
        }
        
        // 모델 초기화
        let model = try await modelBridge.initializeModel(modelType: currentModel.rawValue) as! WhisperModel
        
        // 오디오 파일 정보 가져오기
        let audioFile = try AVAudioFile(forReading: audioFileURL)
        let duration = Double(audioFile.length) / audioFile.processingFormat.sampleRate
        
        // 프로그레스 업데이트 핸들러
        let progressHandler: (Double) -> Void = { progress in
            Task { @MainActor in
                self.progressValue = progress
            }
        }
        
        // 트랜스크립션 옵션 설정
        let options: TranscriptionOptions
        if let language = language, language != "auto" {
            // 지정된 언어가 있으면 해당 언어로 옵션 설정
            options = TranscriptionOptions(
                language: language,
                task: .transcribe,
                temperature: 0.0,
                compressionRatio: 2.4,
                logProbThreshold: -1.0,
                silenceThreshold: 0.6,
                initialPrompt: nil,
                enableWordTimestamps: false,
                translationQuality: 0.7,
                preserveFormats: [.numbers, .names]
            )
        } else {
            // 언어가 지정되지 않았거나 "auto"면 기본 옵션 사용
            options = TranscriptionOptions.default
        }
        
        // 음성 인식 수행
        let transcriptionResult = try await model.transcribe(audioURL: audioFileURL, options: options, progressHandler: progressHandler)
        
        // 결과 생성
        let result = TranscriptionResult(
            text: transcriptionResult.text,
            sourceFile: audioFileURL,
            language: transcriptionResult.detectedLanguage ?? "auto",
            duration: duration,
            timestamp: Date(),
            modelType: currentModel.rawValue
        )
        
        return result
    }
}

/// 다운로드 진행 상황을 추적하는 델리게이트
class ProgressDelegate: NSObject, URLSessionDownloadDelegate {
    private let progressHandler: (Double) -> Void
    
    init(progressHandler: @escaping (Double) -> Void) {
        self.progressHandler = progressHandler
        super.init()
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // 다운로드 완료 시 호출
        progressHandler(1.0)
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        // 다운로드 진행 상황 업데이트
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        progressHandler(progress)
    }
} 
