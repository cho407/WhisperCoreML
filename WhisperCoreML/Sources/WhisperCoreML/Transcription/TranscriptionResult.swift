import Foundation

/// 음성 변환 세그먼트
public struct TranscriptionSegment: Identifiable, Codable, Equatable {
    /// 고유 식별자
    public let id: UUID
    
    /// 세그먼트 인덱스
    public let index: Int
    
    /// 변환된 텍스트
    public let text: String
    
    /// 시작 시간 (초)
    public let start: TimeInterval
    
    /// 종료 시간 (초)
    public let end: TimeInterval
    
    /// 신뢰도 점수 (0.0 ~ 1.0)
    public let confidence: Float?
    
    /// 단어 수준 타임스탬프 (활성화된 경우)
    public let words: [WordTimestamp]?
    
    /// 초기화 메서드
    public init(
        id: UUID = UUID(),
        index: Int,
        text: String,
        start: TimeInterval,
        end: TimeInterval,
        confidence: Float? = nil,
        words: [WordTimestamp]? = nil
    ) {
        self.id = id
        self.index = index
        self.text = text
        self.start = start
        self.end = end
        self.confidence = confidence
        self.words = words
    }
    
    /// 세그먼트 길이 (초)
    public var duration: TimeInterval {
        end - start
    }
}

/// 단어 수준 타임스탬프
public struct WordTimestamp: Identifiable, Codable, Equatable {
    /// 고유 식별자
    public let id: UUID
    
    /// 단어 텍스트
    public let word: String
    
    /// 시작 시간 (초)
    public let start: TimeInterval
    
    /// 종료 시간 (초)
    public let end: TimeInterval
    
    /// 신뢰도 점수 (0.0 ~ 1.0)
    public let confidence: Float?
    
    /// 초기화 메서드
    public init(
        id: UUID = UUID(),
        word: String,
        start: TimeInterval,
        end: TimeInterval,
        confidence: Float? = nil
    ) {
        self.id = id
        self.word = word
        self.start = start
        self.end = end
        self.confidence = confidence
    }
}

/// 음성 변환 결과
public struct TranscriptionResult: Codable, Equatable {
    /// 변환된 텍스트 세그먼트 배열
    public let segments: [TranscriptionSegment]
    
    /// 감지된 언어 (ISO 코드)
    public let detectedLanguage: String?
    
    /// 변환에 사용된 옵션
    public let options: TranscriptionOptions
    
    /// 변환에 걸린 시간 (초)
    public let processingTime: TimeInterval
    
    /// 오디오 길이 (초)
    public let audioDuration: TimeInterval
    
    /// 초기화 메서드
    public init(
        segments: [TranscriptionSegment],
        detectedLanguage: String? = nil,
        options: TranscriptionOptions,
        processingTime: TimeInterval,
        audioDuration: TimeInterval
    ) {
        self.segments = segments
        self.detectedLanguage = detectedLanguage
        self.options = options
        self.processingTime = processingTime
        self.audioDuration = audioDuration
    }
    
    /// 전체 텍스트 (모든 세그먼트 결합)
    public var text: String {
        segments.map { $0.text }.joined(separator: " ")
    }
    
    /// 사전 표현으로 변환
    public func toDictionary() -> [String: Any] {
        var segmentsArray: [[String: Any]] = []
        
        for segment in segments {
            var segmentDict: [String: Any] = [
                "id": segment.id.uuidString,
                "index": segment.index,
                "text": segment.text,
                "start": segment.start,
                "end": segment.end
            ]
            
            if let confidence = segment.confidence {
                segmentDict["confidence"] = confidence
            }
            
            if let words = segment.words {
                var wordsArray: [[String: Any]] = []
                
                for word in words {
                    var wordDict: [String: Any] = [
                        "id": word.id.uuidString,
                        "word": word.word,
                        "start": word.start,
                        "end": word.end
                    ]
                    
                    if let confidence = word.confidence {
                        wordDict["confidence"] = confidence
                    }
                    
                    wordsArray.append(wordDict)
                }
                
                segmentDict["words"] = wordsArray
            }
            
            segmentsArray.append(segmentDict)
        }
        
        var dict: [String: Any] = [
            "segments": segmentsArray,
            "options": options.toDictionary(),
            "processing_time": processingTime,
            "audio_duration": audioDuration
        ]
        
        if let detectedLanguage = detectedLanguage {
            dict["detected_language"] = detectedLanguage
        }
        
        return dict
    }
    
    /// JSON 데이터로 변환
    public func toJSONData() throws -> Data {
        let dict = toDictionary()
        return try JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted])
    }
    
    /// JSON 문자열로 변환
    public func toJSONString() throws -> String {
        let data = try toJSONData()
        guard let string = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "TranscriptionResult", code: 1, userInfo: [NSLocalizedDescriptionKey: "JSON 데이터를 문자열로 변환할 수 없습니다."])
        }
        return string
    }
} 