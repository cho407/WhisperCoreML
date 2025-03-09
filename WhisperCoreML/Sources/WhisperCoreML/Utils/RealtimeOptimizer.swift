import Foundation
import AVFoundation
import CoreML

/// 실시간 최적화 설정
public struct RealtimeOptimizationConfig {
    /// 오디오 버퍼 크기 (초)
    public let bufferDuration: TimeInterval
    /// 처리 간격 (초)
    public let processingInterval: TimeInterval
    /// 최소 신뢰도 점수
    public let minimumConfidence: Double
    /// 중복 제거 임계값 (초)
    public let deduplicationThreshold: TimeInterval
    
    public init(
        bufferDuration: TimeInterval = 30.0,
        processingInterval: TimeInterval = 0.1,
        minimumConfidence: Double = 0.6,
        deduplicationThreshold: TimeInterval = 0.5
    ) {
        self.bufferDuration = bufferDuration
        self.processingInterval = processingInterval
        self.minimumConfidence = minimumConfidence
        self.deduplicationThreshold = deduplicationThreshold
    }
}

/// 실시간 최적화기
public class RealtimeOptimizer {
    private let config: RealtimeOptimizationConfig
    private var lastProcessedTime: TimeInterval = 0
    private var recentTranscriptions: [(text: String, timestamp: TimeInterval)] = []
    
    public init(config: RealtimeOptimizationConfig = RealtimeOptimizationConfig()) {
        self.config = config
    }
    
    /// 중복 제거된 전사 결과 반환
    /// - Parameter segments: 원본 전사 세그먼트 배열
    /// - Returns: 중복이 제거된 전사 세그먼트 배열
    public func deduplicateTranscription(_ segments: [TranscriptionSegment]) -> [TranscriptionSegment] {
        let currentTime = Date().timeIntervalSince1970
        
        // 오래된 전사 결과 제거
        recentTranscriptions = recentTranscriptions.filter { transcription in
            currentTime - transcription.timestamp < config.deduplicationThreshold
        }
        
        // 새로운 세그먼트 필터링
        let filteredSegments = segments.filter { segment in
            // 최소 신뢰도 체크
            guard let confidence = segment.confidence,
                  Double(confidence) >= config.minimumConfidence else {
                return false
            }
            
            // 중복 체크
            let isDuplicate = recentTranscriptions.contains { recent in
                let textSimilarity = calculateSimilarity(recent.text, segment.text)
                let timeGap = abs(currentTime - recent.timestamp)
                return textSimilarity > 0.8 && timeGap < config.deduplicationThreshold
            }
            
            if !isDuplicate {
                recentTranscriptions.append((segment.text, currentTime))
            }
            
            return !isDuplicate
        }
        
        return filteredSegments
    }
    
    /// 처리 시기 확인
    /// - Parameter currentTime: 현재 시간
    /// - Returns: 처리해야 하는지 여부
    public func shouldProcess(at currentTime: TimeInterval) -> Bool {
        guard currentTime - lastProcessedTime >= config.processingInterval else {
            return false
        }
        lastProcessedTime = currentTime
        return true
    }
    
    /// 텍스트 유사도 계산
    private func calculateSimilarity(_ text1: String, _ text2: String) -> Double {
        let set1 = Set(text1.components(separatedBy: " "))
        let set2 = Set(text2.components(separatedBy: " "))
        
        let intersection = set1.intersection(set2).count
        let union = set1.union(set2).count
        
        return Double(intersection) / Double(union)
    }
    
    /// 메모리 사용량 최적화
    public func optimizeMemoryUsage() {
        // 오래된 전사 결과 제거
        let currentTime = Date().timeIntervalSince1970
        recentTranscriptions = recentTranscriptions.filter { transcription in
            currentTime - transcription.timestamp < config.bufferDuration
        }
    }
} 