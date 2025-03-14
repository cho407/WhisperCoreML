import Foundation
import Combine
import WhisperCoreML
import AVFoundation

/// 음성 인식 기능을 담당하는 ViewModel
class TranscriptionViewModel: ObservableObject {
    // MARK: - 속성
    
    // 서비스
    private let audioService = AudioService()
    private let transcriptionService = TranscriptionService()
    
    // 상태 및 데이터
    @Published var transcriptionState: TranscriptionState = .idle
    @Published var transcriptionResults: [TranscriptionResult] = []
    @Published var selectedLanguage: LanguageOption = .autoDetect
    @Published var isPlayingAudio = false
    @Published var selectedFile: AudioFileInfo?
    
    // 오디오 서비스 상태
    @Published var isRecording = false
    @Published var recordingTime: TimeInterval = 0
    @Published var recordedFiles: [AudioFileInfo] = []
    
    // 트랜스크립션 서비스 상태
    @Published var transcriptionProgress: Double = 0
    @Published var availableModels: [ModelInfo] = []
    @Published var selectedModel: WhisperModelType = .tiny
    @Published var downloadingModelInfo: ModelInfo?
    @Published var downloadProgress: Double = 0
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - 초기화
    
    init() {
        setupBindings()
        loadSavedResults()
    }
    
    // MARK: - 바인딩 설정
    
    private func setupBindings() {
        // 오디오 서비스 바인딩
        audioService.$isRecording
            .assign(to: &$isRecording)
        
        audioService.$recordingTime
            .assign(to: &$recordingTime)
        
        audioService.$recordedFiles
            .assign(to: &$recordedFiles)
        
        audioService.$isPlaying
            .assign(to: &$isPlayingAudio)
        
        // 트랜스크립션 서비스 바인딩
        transcriptionService.$progressValue
            .assign(to: &$transcriptionProgress)
        
        transcriptionService.$availableModels
            .assign(to: &$availableModels)
        
        transcriptionService.$currentModel
            .assign(to: &$selectedModel)
    }
    
    // MARK: - 녹음 기능
    
    /// 녹음 시작 또는 중지
    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    /// 녹음 시작
    func startRecording() {
        transcriptionState = .recording
        audioService.startRecording()
    }
    
    /// 녹음 중지 및 인식 시작
    func stopRecording() {
        guard let audioFileURL = audioService.stopRecording() else {
            transcriptionState = .idle
            return
        }
        
        transcribeAudioFile(at: audioFileURL)
    }
    
    // MARK: - 오디오 재생
    
    /// 오디오 파일 재생
    /// - Parameter url: 재생할 오디오 파일 URL
    func playAudio(url: URL) {
        audioService.playAudio(url: url)
    }
    
    /// 오디오 재생 중지
    func stopAudio() {
        audioService.stopPlaying()
    }
    
    // MARK: - 파일 관리
    
    /// 오디오 파일 목록 로드
    func loadAudioFiles() {
        audioService.loadRecordedFiles()
    }
    
    /// 오디오 파일 삭제
    /// - Parameter file: 삭제할 오디오 파일 정보
    func deleteAudioFile(_ file: AudioFileInfo) {
        audioService.deleteRecording(at: file.url)
        
        // 삭제된 파일과 관련된 트랜스크립션 결과도 삭제
        transcriptionResults.removeAll { $0.sourceFile == file.url }
        saveResults()
    }
    
    /// 외부 오디오 파일 임포트
    /// - Parameter url: 임포트할 파일 URL
    /// - Returns: 임포트된 파일 URL (실패시 nil)
    func importAudioFile(from url: URL) -> URL? {
        return audioService.importAudioFile(from: url)
    }
    
    // MARK: - 음성 인식
    
    /// 오디오 파일 트랜스크립션 수행
    /// - Parameter audioFileURL: 인식할 오디오 파일 URL
    func transcribeAudioFile(at audioFileURL: URL) {
        // 진행 중인 트랜스크립션이 있으면 무시
        guard case .idle = transcriptionState else { return }
        guard case .recording = transcriptionState else { return }
        
        transcriptionState = .processing
        
        // 트랜스크립션 설정
        transcriptionService.currentModel = selectedModel
        
        // 비동기 트랜스크립션 시작
        Task {
            do {
                let language = selectedLanguage == .autoDetect ? nil : selectedLanguage.rawValue
                let result = try await transcriptionService.transcribeAudioFile(at: audioFileURL, language: language)
                
                await MainActor.run {
                    // 결과 저장 및 상태 업데이트
                    transcriptionResults.insert(result, at: 0)
                    transcriptionState = .completed(result)
                    saveResults()
                }
            } catch {
                await MainActor.run {
                    transcriptionState = .failed(error)
                }
            }
        }
    }
    
    /// 모델 다운로드
    /// - Parameter modelType: 다운로드할 모델 타입
    func downloadModel(_ modelType: WhisperModelType) {
        // 이미 다운로드 중인 경우 무시
        guard downloadingModelInfo == nil else { return }
        
        // 다운로드할 모델 정보 설정
        let modelInfo = availableModels.first { $0.type == modelType }!
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
                    switch completion {
                    case .finished:
                        // 다운로드 완료
                        self?.downloadingModelInfo = nil
                        // 모델 목록 갱신
                        self?.transcriptionService.loadAvailableModels()
                    case .failure(let error):
                        // 다운로드 실패
                        print("모델 다운로드 실패: \(error.localizedDescription)")
                        self?.downloadingModelInfo = nil
                    }
                },
                receiveValue: { [weak self] progress in
                    // 진행 상황 업데이트
                    self?.downloadProgress = progress
                    self?.downloadingModelInfo = ModelInfo(
                        type: modelType,
                        isDownloaded: false,
                        downloadProgress: progress,
                        isBuiltIn: modelInfo.isBuiltIn
                    )
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - 결과 저장 및 로드
    
    /// 트랜스크립션 결과 저장
    private func saveResults() {
        do {
            let encoder = JSONEncoder()
            // Date 인코딩 방식 설정
            encoder.dateEncodingStrategy = .secondsSince1970
            
            // 직접 결과 배열을 인코딩
            let resultsData = try encoder.encode(transcriptionResults)
            
            let fileURL = getDocumentsDirectory().appendingPathComponent("transcription_results.json")
            try resultsData.write(to: fileURL)
        } catch {
            print("결과 저장 실패: \(error.localizedDescription)")
        }
    }
    
    /// 저장된 트랜스크립션 결과 로드
    private func loadSavedResults() {
        let fileURL = getDocumentsDirectory().appendingPathComponent("transcription_results.json")
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            // Date 디코딩 방식 설정
            decoder.dateDecodingStrategy = .secondsSince1970
            
            // 직접 결과 배열로 디코딩
            transcriptionResults = try decoder.decode([TranscriptionResult].self, from: data)
        } catch {
            print("결과 로드 실패: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 유틸리티
    
    private func getDocumentsDirectory() -> URL {
        // macOS에서는 Application Support 디렉토리 사용
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupportDirectory = paths[0].appendingPathComponent("WhisperCoreMLSample", isDirectory: true)
        
        // 디렉토리가 없으면 생성
        if !FileManager.default.fileExists(atPath: appSupportDirectory.path) {
            try? FileManager.default.createDirectory(at: appSupportDirectory, withIntermediateDirectories: true, attributes: nil)
        }
        
        return appSupportDirectory
    }
} 