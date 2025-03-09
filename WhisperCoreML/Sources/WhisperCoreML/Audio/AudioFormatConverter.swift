import Foundation
import AVFoundation
#if canImport(YouTubeDL)
import YouTubeDL
#endif

/// 지원하는 오디오 형식
public enum AudioFormat {
    case wav
    case mp3
    case aac
    case m4a
    case flac
    case ogg
    case video  // 비디오 파일에서 오디오 추출
    case youtube // YouTube URL
}

/// 오디오 처리 설정
public struct AudioProcessingOptions {
    public let sampleRate: Double
    public let channelCount: Int
    public let bitDepth: Int
    public let normalizeAudio: Bool
    public let removeSilence: Bool
    
    public static let `default` = AudioProcessingOptions(
        sampleRate: 16000,
        channelCount: 1,
        bitDepth: 16,
        normalizeAudio: true,
        removeSilence: false
    )
}

/// 오디오 스트림 버퍼
public actor AudioStreamBuffer {
    private var buffer: [Float]
    private let maxSize: Int
    
    public init(maxSize: Int = 480000) { // 30초 @ 16kHz
        self.buffer = []
        self.maxSize = maxSize
    }
    
    public func append(_ samples: [Float]) {
        buffer.append(contentsOf: samples)
        if buffer.count > maxSize {
            buffer.removeFirst(buffer.count - maxSize)
        }
    }
    
    public func clear() {
        buffer.removeAll(keepingCapacity: true)  // 메모리 재사용을 위해 keepingCapacity 추가
    }
    
    public func getData() -> [Float] {
        return Array(buffer)  // 버퍼의 복사본을 반환하여 데이터 격리
    }
}

/// 오디오 형식 변환기
public actor AudioFormatConverter {
    /// 싱글톤 인스턴스
    public static let shared = AudioFormatConverter()
    
    /// 임시 파일 디렉토리
    private let tempDirectory: URL
    
    /// 오디오 엔진
    private var audioEngine: AVAudioEngine?
    
    /// 스트림 버퍼
    private var streamBuffer: AudioStreamBuffer
    
    private init() {
        self.tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("WhisperAudioTemp", isDirectory: true)
        self.streamBuffer = AudioStreamBuffer()
        try? FileManager.default.createDirectory(at: tempDirectory,
                                                   withIntermediateDirectories: true)
    }
    
    /// 오디오 URL을 WAV 형식으로 변환
    /// - Parameters:
    ///   - url: 원본 오디오/비디오 URL
    ///   - options: 오디오 처리 옵션
    /// - Returns: 변환된 WAV 파일 URL
    public nonisolated func convertToWAV(
        _ url: URL,
        options: AudioProcessingOptions = .default
    ) async throws -> URL {
        let asset = AVAsset(url: url)
        
        // 오디오 트랙 확인
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        if audioTracks.isEmpty {
            throw WhisperError.audioProcessingFailed("오디오 트랙을 찾을 수 없습니다.")
        }
        
        let outputURL = tempDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")
        
        // MainActor에서 export 세션 생성 및 실행
        return try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor in
                do {
                    // 오디오 설정
                    guard let exportSession = AVAssetExportSession(
                        asset: asset,
                        presetName: AVAssetExportPresetAppleM4A
                    ) else {
                        throw WhisperError.audioProcessingFailed("Export 세션을 생성할 수 없습니다.")
                    }
                    
                    exportSession.outputURL = outputURL
                    exportSession.outputFileType = .wav
                    exportSession.audioTimePitchAlgorithm = .spectral
                    exportSession.audioMix = try await createAudioMixNonisolated(for: asset, options: options)
                    
                    // 변환 실행
                    await withCheckedContinuation { (innerContinuation: CheckedContinuation<Void, Never>) in
                        exportSession.exportAsynchronously {
                            innerContinuation.resume()
                        }
                    }
                    
                    switch exportSession.status {
                    case .completed:
                        continuation.resume(returning: outputURL)
                    case .failed:
                        continuation.resume(throwing: exportSession.error ?? WhisperError.audioProcessingFailed("알 수 없는 오류"))
                    case .cancelled:
                        continuation.resume(throwing: WhisperError.audioProcessingFailed("변환이 취소되었습니다."))
                    default:
                        continuation.resume(throwing: WhisperError.audioProcessingFailed("예상치 못한 상태: \(exportSession.status.rawValue)"))
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// 실시간 오디오 스트리밍 시작
    /// - Parameter options: 오디오 처리 옵션
    public func startStreaming(
        options: AudioProcessingOptions = .default
    ) async throws {
        #if os(iOS)
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try await audioSession.setCategory(.record, mode: .measurement, options: [.mixWithOthers, .allowBluetooth])
            try await audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            throw WhisperError.audioEngineError("오디오 세션 설정 실패: \(error.localizedDescription)")
        }
        #endif
        
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            throw WhisperError.audioProcessingFailed("오디오 엔진을 생성할 수 없습니다.")
        }
        
        let inputNode = audioEngine.inputNode
        let bus = 0
        
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: options.sampleRate,
            channels: AVAudioChannelCount(options.channelCount),
            interleaved: false
        ) else {
            throw WhisperError.audioProcessingFailed("오디오 포맷을 생성할 수 없습니다.")
        }
        
        inputNode.installTap(
            onBus: bus,
            bufferSize: 4096,
            format: format
        ) { [weak self] buffer, _ in
            guard let self = self else { return }
            
            let frames = buffer.frameLength
            let channelCount = Int(buffer.format.channelCount)
            var samples: [Float] = Array(repeating: 0, count: Int(frames))
            
            if let channelData = buffer.floatChannelData {
                for frame in 0..<Int(frames) {
                    var sum: Float = 0
                    for channel in 0..<channelCount {
                        sum += channelData[channel][frame]
                    }
                    samples[frame] = sum / Float(channelCount)
                }
            }
            
            if options.normalizeAudio {
                let maxAmplitude = samples.map(abs).max() ?? 1
                if maxAmplitude > 0 {
                    samples = samples.map { $0 / maxAmplitude }
                }
            }
            
            Task {
                await self.streamBuffer.append(samples)
            }
        }
        
        try audioEngine.start()
    }
    
    /// 실시간 스트리밍 중지
    public func stopStreaming() async throws {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil
        
        #if os(iOS)
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setActive(false)
        #endif
        
        await streamBuffer.clear()
    }
    
    /// 현재 스트림 데이터 가져오기
    public func getStreamData() async -> [Float] {
        return await streamBuffer.getData()
    }
    
    /// 임시 파일 정리
    public nonisolated func cleanup() {
        let fileManager = FileManager.default
        try? fileManager.removeItem(at: tempDirectory)
        try? fileManager.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }
    
    // MARK: - Private Methods
    
    private nonisolated func createAudioMixNonisolated(
        for asset: AVAsset,
        options: AudioProcessingOptions
    ) async throws -> AVAudioMix? {
        do {
            guard let audioTrack = try await asset.loadTracks(withMediaType: .audio).first else {
                return nil
            }
            
            let parameters = AVMutableAudioMixInputParameters(track: audioTrack)
            
            if options.normalizeAudio {
                parameters.audioTimePitchAlgorithm = .spectral
                let timeRange = try await audioTrack.load(.timeRange)
                parameters.setVolumeRamp(
                    fromStartVolume: 1.0,
                    toEndVolume: 1.0,
                    timeRange: timeRange
                )
            }
            
            let audioMix = AVMutableAudioMix()
            audioMix.inputParameters = [parameters]
            return audioMix
        } catch {
            return nil
        }
    }
    
    deinit {
        cleanup()
    }
}
