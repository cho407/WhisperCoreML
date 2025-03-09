import Foundation
import AVFoundation
import Combine

/// 실시간 음성 인식 결과
public struct RealtimeTranscriptionResult {
    public let text: String
    public let timestamp: Date
    public let isFinal: Bool
}

/// 실시간 음성 인식기
public class RealtimeTranscriber {
    /// Whisper 모델
    private let model: WhisperModel
    
    /// 오디오 엔진
    private let audioEngine: AVAudioEngine
    
    /// 설정
    private let configuration: RealtimeConfiguration
    
    /// 오디오 버퍼
    private let audioBuffer: AudioBuffer
    
    /// 오디오 세션
    private let audioSession: AudioSessionProtocol
    
    /// 처리 상태
    @Published public private(set) var isProcessing: Bool = false
    
    /// 취소 토큰
    private var cancellables = Set<AnyCancellable>()
    
    /// 초기화
    /// - Parameters:
    ///   - model: Whisper 모델
    ///   - configuration: 실시간 처리 설정
    public init(model: WhisperModel, configuration: RealtimeConfiguration = .default) {
        self.model = model
        self.configuration = configuration
        self.audioEngine = AVAudioEngine()
        self.audioBuffer = AudioBuffer(configuration: configuration)
        self.audioSession = AudioSessionFactory.createAudioSession()
    }
    
    /// 음성 인식 시작
    /// - Returns: 실시간 인식 결과 스트림
    public func startTranscribing() -> AsyncStream<RealtimeTranscriptionResult> {
        AsyncStream { continuation in
            Task {
                do {
                    try setupAudioSession()
                    try setupAudioEngine()
                    audioEngine.prepare()
                    try audioEngine.start()
                    
                    isProcessing = true
                    
                    while isProcessing {
                        // 세그먼트 처리
                        let segment = audioBuffer.getSegment(
                            duration: configuration.segmentDuration,
                            sampleRate: configuration.sampleRate
                        )
                        
                        if !segment.isEmpty {
                            // 모델 처리
                            let result = try await processAudioSegment(segment)
                            continuation.yield(result)
                        }
                        
                        try await Task.sleep(nanoseconds: UInt64(0.1 * Double(NSEC_PER_SEC)))
                    }
                    
                    continuation.finish()
                } catch {
                    print("Error in transcription: \(error)")
                    continuation.finish()
                }
            }
        }
    }
    
    /// 음성 인식 중지
    public func stopTranscribing() {
        isProcessing = false
        audioEngine.stop()
        audioBuffer.clear()
    }
    
    // MARK: - Private Methods
    
    private func setupAudioSession() throws {
        try audioSession.setup()
    }
    
    private func setupAudioEngine() throws {
        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        
        input.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
            guard let self = self else { return }
            
            // PCM 버퍼를 Float 배열로 변환
            let frameCount = buffer.frameLength
            let samples = Array(UnsafeBufferPointer(start: buffer.floatChannelData?[0],
                                                   count: Int(frameCount)))
            
            // 버퍼에 추가
            self.audioBuffer.append(samples)
        }
    }
    
    private func processAudioSegment(_ segment: [Float]) async throws -> RealtimeTranscriptionResult {
        // 오디오 처리
        let audioData = AudioData(
            samples: segment,
            sampleRate: configuration.sampleRate
        )
        
        // 멜 스펙트로그램 추출
        let melSpectrogram = try model.audioProcessor.extractMelSpectrogram(from: audioData)
        
        // 모델 입력 준비
        let modelInput = try model.prepareModelInput(
            melSpectrogram: melSpectrogram,
            options: .default
        )
        
        // 모델 실행
        guard let modelOutput = try? model.model?.prediction(from: modelInput) else {
            throw WhisperError.modelOutputProcessingFailed("모델 실행 실패")
        }
        
        // 결과 처리
        let segments = try await model.processModelOutput(modelOutput, options: .default, timeOffset: 0)
        let text = segments.map { $0.text }.joined(separator: " ")
        
        return RealtimeTranscriptionResult(
            text: text,
            timestamp: Date(),
            isFinal: true
        )
    }
} 
