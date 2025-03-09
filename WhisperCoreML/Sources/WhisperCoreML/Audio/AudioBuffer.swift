import Foundation
import AVFoundation

/// 원형 오디오 버퍼
public class AudioBuffer {
    /// 버퍼 데이터
    private var buffer: [Float]
    
    /// 버퍼 용량
    private let capacity: Int
    
    /// 쓰기 위치
    private var writeIndex: Int = 0
    
    /// 초기화
    /// - Parameters:
    ///   - configuration: 실시간 처리 설정
    public init(configuration: RealtimeConfiguration) {
        self.capacity = Int(configuration.bufferDuration * configuration.sampleRate)
        self.buffer = Array(repeating: 0.0, count: capacity)
    }
    
    /// 오디오 데이터 추가
    /// - Parameter samples: 오디오 샘플 데이터
    public func append(_ samples: [Float]) {
        for sample in samples {
            buffer[writeIndex] = sample
            writeIndex = (writeIndex + 1) % capacity
        }
    }
    
    /// 세그먼트 가져오기
    /// - Parameter duration: 세그먼트 지속 시간
    /// - Returns: 오디오 세그먼트 데이터
    public func getSegment(duration: TimeInterval, sampleRate: Double) -> [Float] {
        let sampleCount = Int(duration * sampleRate)
        guard sampleCount <= capacity else { return [] }
        
        var segment: [Float] = []
        segment.reserveCapacity(sampleCount)
        
        let startIndex = (writeIndex - sampleCount + capacity) % capacity
        
        if startIndex + sampleCount <= capacity {
            segment.append(contentsOf: buffer[startIndex..<(startIndex + sampleCount)])
        } else {
            let firstPart = buffer[startIndex..<capacity]
            let secondPart = buffer[0..<(sampleCount - firstPart.count)]
            segment.append(contentsOf: firstPart)
            segment.append(contentsOf: secondPart)
        }
        
        return segment
    }
    
    /// 버퍼 초기화
    public func clear() {
        buffer = Array(repeating: 0.0, count: capacity)
        writeIndex = 0
    }
} 