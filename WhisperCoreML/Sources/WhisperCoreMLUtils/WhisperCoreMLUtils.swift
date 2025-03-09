// WhisperCoreMLUtils.swift
// Whisper CoreML 유틸리티 기능

import Foundation
import Combine

/// WhisperCoreMLUtils 모듈의 주요 기능을 제공하는 클래스
public class WhisperCoreMLUtils {
    /// 싱글톤 인스턴스
    public static let shared = WhisperCoreMLUtils()
    
    /// 초기화
    private init() {}
    
    /// 모듈 버전
    public static let version = "1.0.0"
    
    /// 모듈 정보
    public static func moduleInfo() -> [String: Any] {
        return [
            "name": "WhisperCoreMLUtils",
            "version": version,
            "description": "Whisper CoreML 모델 변환 및 유틸리티 기능"
        ]
    }
    
    /// 모듈 초기화
    public func initialize() {
        print("WhisperCoreMLUtils 모듈이 초기화되었습니다. 버전: \(WhisperCoreMLUtils.version)")
    }
}

/// 자막 세그먼트 유형 (SubtitleUtils.swift와 중복되지 않도록 별도 정의)
public struct WhisperSubtitleSegment: Identifiable, Codable, Equatable {
    /// 고유 식별자
    public let id: UUID
    
    /// 자막 텍스트
    public let text: String
    
    /// 시작 시간 (초)
    public let startTime: TimeInterval
    
    /// 종료 시간 (초)
    public let endTime: TimeInterval
    
    /// 초기화 메서드
    public init(
        id: UUID = UUID(),
        text: String,
        startTime: TimeInterval,
        endTime: TimeInterval
    ) {
        self.id = id
        self.text = text
        self.startTime = startTime
        self.endTime = endTime
    }
} 