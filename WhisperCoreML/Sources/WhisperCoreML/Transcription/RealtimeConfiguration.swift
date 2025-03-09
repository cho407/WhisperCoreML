import Foundation

/// 실시간 처리 설정
public struct RealtimeConfiguration {
    /// 기본 설정
    public static let `default` = RealtimeConfiguration()
    
    /// 세그먼트 지속 시간 (초)
    public let segmentDuration: TimeInterval
    
    /// 버퍼 지속 시간 (초)
    public let bufferDuration: TimeInterval
    
    /// 샘플 레이트
    public let sampleRate: Double
    
    /// 초기화
    public init(
        segmentDuration: TimeInterval = 5.0,
        bufferDuration: TimeInterval = 30.0,
        sampleRate: Double = 16000.0
    ) {
        self.segmentDuration = segmentDuration
        self.bufferDuration = bufferDuration
        self.sampleRate = sampleRate
    }
} 