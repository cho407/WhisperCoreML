// AudioProcessor.swift
// 오디오 처리 관련 코드

import Foundation
import AVFoundation
import Accelerate

/// 오디오 처리 클래스
public class AudioProcessor {
    /// Whisper 모델에서 사용하는 기본 샘플 레이트 (16kHz)
    public static let whisperSampleRate: Double = 16000.0
    
    /// 초기화 메서드
    public init() {}
    
    /// 오디오 파일에서 AudioData 생성
    public func loadAudioFile(url: URL) async throws -> AudioData {
        // 오디오 파일 로드
        let audioData = try AudioData.fromAudioFile(url: url)
        
        // Whisper 모델에 맞게 처리
        return try await processAudioForWhisper(audioData)
    }
    
    /// 오디오 데이터를 Whisper 모델에 맞게 처리
    public func processAudioForWhisper(_ audioData: AudioData) async throws -> AudioData {
        // 16kHz로 리샘플링
        let resampledData = resampleAudio(audioData, to: AudioProcessor.whisperSampleRate)
        
        // 정규화
        let normalizedData = normalizeAudio(resampledData)
        
        return normalizedData
    }
    
    /// 오디오 데이터에서 멜 스펙트로그램 추출
    /// - Parameter audioData: 오디오 데이터
    /// - Returns: 멜 스펙트로그램 배열
    public func extractMelSpectrogram(from audioData: AudioData) throws -> [Float] {
        return try audioToMelSpectrogram(audioData)
    }
    
    /// 오디오 데이터 리샘플링 헬퍼 메서드
    private func resampleAudio(_ audioData: AudioData, to targetSampleRate: Double) -> AudioData {
        // 이미 목표 샘플 레이트와 같으면 그대로 반환
        if audioData.sampleRate == targetSampleRate {
            return audioData
        }
        
        // 리샘플링 비율 계산
        let ratio = targetSampleRate / audioData.sampleRate
        let targetLength = Int(Double(audioData.samples.count) * ratio)
        var resampledSamples = [Float](repeating: 0.0, count: targetLength)
        
        // 선형 보간법을 사용한 리샘플링
        for i in 0..<targetLength {
            let sourceIndex = Double(i) / ratio
            let sourceIndexFloor = Int(sourceIndex)
            let sourceIndexCeil = min(sourceIndexFloor + 1, audioData.samples.count - 1)
            let fraction = sourceIndex - Double(sourceIndexFloor)
            
            // 선형 보간
            resampledSamples[i] = audioData.samples[sourceIndexFloor] * Float(1.0 - fraction) + audioData.samples[sourceIndexCeil] * Float(fraction)
        }
        
        return AudioData(samples: resampledSamples, sampleRate: targetSampleRate)
    }
    
    /// 오디오 데이터 정규화 헬퍼 메서드
    private func normalizeAudio(_ audioData: AudioData) -> AudioData {
        guard !audioData.samples.isEmpty else {
            return audioData
        }
        
        // 최대 절대값 찾기
        let maxAmplitude = audioData.samples.map { abs($0) }.max() ?? 1.0
        
        // 최대값이 이미 1.0 이하면 그대로 반환
        if maxAmplitude <= 1.0 {
            return audioData
        }
        
        // 정규화된 샘플 생성
        let normalizedSamples = audioData.samples.map { $0 / maxAmplitude }
        return AudioData(samples: normalizedSamples, sampleRate: audioData.sampleRate)
    }
    
    /// 오디오 파일을 WAV 형식으로 변환
    public func convertToWAV(from sourceURL: URL, to destinationURL: URL) async throws {
        // 오디오 파일 로드
        let audioData = try AudioData.fromAudioFile(url: sourceURL)
        
        // WAV 파일로 저장
        try audioData.saveAsWAV(to: destinationURL)
    }
    
    /// 오디오 파일에서 특정 시간 범위 추출
    public func extractAudioSegment(from url: URL, startTime: TimeInterval, endTime: TimeInterval) async throws -> AudioData {
        // 오디오 파일 로드
        let audioData = try AudioData.fromAudioFile(url: url)
        
        // 시간 범위 추출
        return audioData.slice(from: startTime, to: endTime)
    }
    
    /// 오디오 데이터를 Mel 스펙트로그램으로 변환
    public func audioToMelSpectrogram(_ audioData: AudioData, frameSize: Int = 400, hopSize: Int = 160, melBands: Int = 80) throws -> [Float] {
        // Whisper 모델에 맞게 처리된 오디오 데이터인지 확인
        let processedAudio = audioData.sampleRate == AudioProcessor.whisperSampleRate
            ? audioData
            : resampleAudio(audioData, to: AudioProcessor.whisperSampleRate)
        
        // 샘플 데이터
        let samples = processedAudio.samples
        
        // 프레임 수 계산
        let numFrames = 1 + (samples.count - frameSize) / hopSize
        
        // 결과 배열 초기화
        var melSpectrogram = [Float](repeating: 0.0, count: numFrames * melBands)
        
        // FFT 설정
        let fftSetup = vDSP_DFT_zop_CreateSetup(
            nil,
            UInt(frameSize),
            vDSP_DFT_Direction.FORWARD
        )
        
        // 윈도우 함수 (Hann 윈도우)
        var window = [Float](repeating: 0.0, count: frameSize)
        vDSP_hann_window(&window, vDSP_Length(frameSize), Int32(0))
        
        // 각 프레임에 대해 처리
        for i in 0..<numFrames {
            let startIdx = i * hopSize
            let endIdx = min(startIdx + frameSize, samples.count)
            
            // 현재 프레임 추출
            var frame = Array(samples[startIdx..<endIdx])
            
            // 프레임 크기가 부족하면 0으로 패딩
            if frame.count < frameSize {
                frame.append(contentsOf: [Float](repeating: 0.0, count: frameSize - frame.count))
            }
            
            // 윈도우 적용
            vDSP_vmul(frame, 1, window, 1, &frame, 1, vDSP_Length(frameSize))
            
            // FFT 수행 (실수 부분과 허수 부분 분리)
            var realPart = [Float](repeating: 0.0, count: frameSize / 2)
            var imagPart = [Float](repeating: 0.0, count: frameSize / 2)
            
            // 실수 입력을 복소수 FFT로 변환
            realPart.withUnsafeMutableBufferPointer { realPtr in
                imagPart.withUnsafeMutableBufferPointer { imagPtr in
                    var splitComplex = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)
                    
                    frame.withUnsafeBufferPointer { framePtr in
                        let frameBaseAddress = framePtr.baseAddress!
                        
                        // DSPComplex 배열로 변환
                        let dspComplexPointer = UnsafeRawPointer(frameBaseAddress).bindMemory(to: DSPComplex.self, capacity: frameSize / 2)
                        
                        vDSP_ctoz(dspComplexPointer, 2, &splitComplex, 1, vDSP_Length(frameSize / 2))
                    }
                    
                    // FFT 수행
                    if let fftSetup = fftSetup {
                        vDSP_fft_zrip(fftSetup, &splitComplex, 1, vDSP_Length(log2(Float(frameSize))), FFTDirection(kFFTDirection_Forward))
                    }
                    
                    // 파워 스펙트럼 계산
                    var magnitudes = [Float](repeating: 0.0, count: frameSize / 2)
                    vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(frameSize / 2))
                    
                    // Mel 필터뱅크 적용 (간소화된 버전)
                    // 실제 구현에서는 Mel 필터뱅크를 정확히 계산해야 함
                    for j in 0..<melBands {
                        let startBin = j * (frameSize / 2) / melBands
                        let endBin = min((j + 1) * (frameSize / 2) / melBands, frameSize / 2)
                        
                        var sum: Float = 0.0
                        for k in startBin..<endBin {
                            sum += magnitudes[k]
                        }
                        
                        // 로그 스케일 적용
                        let logMel = sum > 1e-10 ? log10(sum) : -10.0
                        melSpectrogram[i * melBands + j] = logMel
                    }
                }
            }
        }
        
        // FFT 설정 해제
        if let fftSetup = fftSetup {
            vDSP_DFT_DestroySetup(fftSetup)
        }
        
        return melSpectrogram
    }
    
    /// 오디오 데이터의 무음 구간 감지
    public func detectSilence(in audioData: AudioData, threshold: Float = 0.01, minDuration: TimeInterval = 0.5) -> [ClosedRange<TimeInterval>] {
        let samples = audioData.samples
        let sampleRate = audioData.sampleRate
        let minSamples = Int(minDuration * sampleRate)
        
        var silenceRanges = [ClosedRange<TimeInterval>]()
        var silenceStart: Int? = nil
        
        for i in 0..<samples.count {
            let amplitude = abs(samples[i])
            
            // 무음 시작 감지
            if amplitude < threshold && silenceStart == nil {
                silenceStart = i
            }
            // 무음 종료 감지
            else if (amplitude >= threshold || i == samples.count - 1) && silenceStart != nil {
                let silenceEnd = i
                
                // 최소 지속 시간 이상인 경우만 포함
                if silenceEnd - silenceStart! >= minSamples {
                    let startTime = TimeInterval(silenceStart!) / sampleRate
                    let endTime = TimeInterval(silenceEnd) / sampleRate
                    silenceRanges.append(startTime...endTime)
                }
                
                silenceStart = nil
            }
        }
        
        return silenceRanges
    }
    
    /// 오디오 데이터의 음성 활성도 감지 (VAD)
    public func detectVoiceActivity(in audioData: AudioData, threshold: Float = 0.02, frameDuration: TimeInterval = 0.03) -> [ClosedRange<TimeInterval>] {
        let samples = audioData.samples
        let sampleRate = audioData.sampleRate
        let frameSize = Int(frameDuration * sampleRate)
        
        var voiceRanges = [ClosedRange<TimeInterval>]()
        var voiceStart: Int? = nil
        
        // 각 프레임에 대해 처리
        for i in stride(from: 0, to: samples.count, by: frameSize) {
            let endIdx = min(i + frameSize, samples.count)
            let frame = Array(samples[i..<endIdx])
            
            // 프레임의 에너지 계산
            var energy: Float = 0.0
            vDSP_measqv(frame, 1, &energy, vDSP_Length(frame.count))
            
            // 음성 시작 감지
            if energy > threshold * threshold && voiceStart == nil {
                voiceStart = i
            }
            // 음성 종료 감지
            else if (energy <= threshold * threshold || i + frameSize >= samples.count) && voiceStart != nil {
                let voiceEnd = i + frameSize
                
                let startTime = TimeInterval(voiceStart!) / sampleRate
                let endTime = TimeInterval(min(voiceEnd, samples.count)) / sampleRate
                voiceRanges.append(startTime...endTime)
                
                voiceStart = nil
            }
        }
        
        return voiceRanges
    }
} 