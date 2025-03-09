import Foundation
import AVFoundation

/// 오디오 데이터 구조체
public struct AudioData: Equatable {
    /// 오디오 샘플 배열 (Float 형식)
    public let samples: [Float]
    
    /// 샘플 레이트 (Hz)
    public let sampleRate: Double
    
    /// 초기화 메서드
    public init(samples: [Float], sampleRate: Double) {
        self.samples = samples
        self.sampleRate = sampleRate
    }
    
    /// 오디오 길이 (초)
    public var duration: TimeInterval {
        TimeInterval(samples.count) / sampleRate
    }
    
    /// 특정 시간 범위의 오디오 데이터 추출
    public func slice(from startTime: TimeInterval, to endTime: TimeInterval) -> AudioData {
        let startSample = Int(startTime * sampleRate)
        let endSample = min(Int(endTime * sampleRate), samples.count)
        
        guard startSample < endSample, startSample >= 0, endSample <= samples.count else {
            return AudioData(samples: [], sampleRate: sampleRate)
        }
        
        let slicedSamples = Array(samples[startSample..<endSample])
        return AudioData(samples: slicedSamples, sampleRate: sampleRate)
    }
    
    /// 오디오 데이터를 WAV 파일로 저장
    public func saveAsWAV(to url: URL) throws {
        // 오디오 설정
        let audioFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        )
        
        guard let audioFormat = audioFormat else {
            throw NSError(domain: "AudioData", code: 1, userInfo: [NSLocalizedDescriptionKey: "오디오 포맷을 생성할 수 없습니다."])
        }
        
        // 오디오 파일 생성
        let audioFile = try AVAudioFile(
            forWriting: url,
            settings: audioFormat.settings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )
        
        // 버퍼 생성
        guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: AVAudioFrameCount(samples.count)) else {
            throw NSError(domain: "AudioData", code: 2, userInfo: [NSLocalizedDescriptionKey: "오디오 버퍼를 생성할 수 없습니다."])
        }
        
        // 샘플 데이터 복사
        buffer.frameLength = AVAudioFrameCount(samples.count)
        let channelData = buffer.floatChannelData?[0]
        
        for i in 0..<samples.count {
            channelData?[i] = samples[i]
        }
        
        // 파일에 쓰기
        try audioFile.write(from: buffer)
    }
    
    /// 오디오 파일에서 AudioData 생성
    public static func fromAudioFile(url: URL) throws -> AudioData {
        // 오디오 파일 열기
        let audioFile = try AVAudioFile(forReading: url)
        let format = audioFile.processingFormat
        let frameCount = AVAudioFrameCount(audioFile.length)
        
        // 버퍼 생성
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw NSError(domain: "AudioData", code: 3, userInfo: [NSLocalizedDescriptionKey: "오디오 버퍼를 생성할 수 없습니다."])
        }
        
        // 파일에서 읽기
        try audioFile.read(into: buffer)
        
        // 샘플 데이터 추출
        var samples = [Float]()
        
        // 모노 또는 스테레오 처리
        if let channelData = buffer.floatChannelData {
            let channelCount = Int(format.channelCount)
            
            // 모든 프레임에 대해
            for frame in 0..<Int(buffer.frameLength) {
                var sample: Float = 0.0
                
                // 모든 채널의 평균 계산 (모노로 변환)
                for channel in 0..<channelCount {
                    sample += channelData[channel][frame]
                }
                
                samples.append(sample / Float(channelCount))
            }
        }
        
        return AudioData(samples: samples, sampleRate: format.sampleRate)
    }
} 