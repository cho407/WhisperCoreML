//
//  MemoryLeakTests.swift
//  WhisperCoreML
//
//  Created by Hyunggu Cho
//

import XCTest
@testable import WhisperCoreML

/// 메모리 누수 테스트를 위한 테스트 클래스
final class MemoryLeakTests: XCTestCase {
    
    // MARK: - 테스트 설정 및 해제
    
    override func setUpWithError() throws {
        // 각 테스트 메서드 실행 전 설정 코드
    }
    
    override func tearDownWithError() throws {
        // 각 테스트 메서드 실행 후 정리 코드
    }
    
    // MARK: - 메모리 누수 테스트
    
    /// 트랜스크립션 세그먼트 메모리 누수 테스트
    func testTranscriptionSegmentMemoryLeak() {
        // 강한 참조 사이클이 없는지 확인
        let segment = TranscriptionSegment(
            id: UUID(),
            index: 1,
            text: "안녕하세요",
            start: 0.0,
            end: 2.5,
            confidence: 0.95
        )
        
        // 메모리 누수 추적
        trackForMemoryLeaks(on: segment as AnyObject)
    }
    
    /// 트랜스크립션 결과 메모리 누수 테스트
    func testTranscriptionResultMemoryLeak() {
        // 테스트용 세그먼트 생성
        let segments = [
            TranscriptionSegment(
                id: UUID(),
                index: 0,
                text: "안녕하세요",
                start: 0.0,
                end: 2.5,
                confidence: 0.95
            )
        ]
        
        // 트랜스크립션 결과 생성
        let result = TranscriptionResult(
            segments: segments,
            detectedLanguage: "ko",
            options: TranscriptionOptions.default,
            processingTime: 1.5,
            audioDuration: 5.0
        )
        
        // 메모리 누수 추적
        trackForMemoryLeaks(on: result as AnyObject)
    }
    
    /// 단어 타임스탬프 메모리 누수 테스트
    func testWordTimestampMemoryLeak() {
        // 단어 타임스탬프 생성
        let wordTimestamp = WordTimestamp(
            id: UUID(),
            word: "안녕",
            start: 1.0,
            end: 1.5,
            confidence: 0.9
        )
        
        // 메모리 누수 추적
        trackForMemoryLeaks(on: wordTimestamp as AnyObject)
    }
    
    /// 트랜스크립션 옵션 메모리 누수 테스트
    func testTranscriptionOptionsMemoryLeak() {
        // 사용자 정의 옵션 생성
        let options = TranscriptionOptions(
            language: "ko",
            task: .translate,
            temperature: 0.5,
            compressionRatio: 2.0,
            logProbThreshold: -0.5,
            silenceThreshold: 0.7,
            initialPrompt: "테스트",
            enableWordTimestamps: true,
            translationQuality: 0.8,
            preserveFormats: [.numbers, .names]
        )
        
        // 메모리 누수 추적
        trackForMemoryLeaks(on: options as AnyObject)
    }
    
    /// 비싱글톤 객체 생성 및 메모리 누수 테스트
    func testNonSingletonObjectMemoryLeak() {
        // 일반 객체 생성 (비싱글톤)
        class TestObject {
            var name: String
            
            init(name: String) {
                self.name = name
            }
        }
        
        let testObject = TestObject(name: "테스트 객체")
        
        // 메모리 누수 추적
        trackForMemoryLeaks(on: testObject)
    }
} 