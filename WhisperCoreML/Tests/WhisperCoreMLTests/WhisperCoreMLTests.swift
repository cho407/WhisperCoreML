//
//  WhisperCoreMLTests.swift
//  WhisperCoreML
//
//  Created by Hyunggu Cho
//

import XCTest
@testable import WhisperCoreML

final class WhisperCoreMLTests: XCTestCase {
    
    // MARK: - 테스트 설정 및 해제
    
    override func setUpWithError() throws {
        // 각 테스트 메서드 실행 전 설정 코드
    }
    
    override func tearDownWithError() throws {
        // 각 테스트 메서드 실행 후 정리 코드
    }
    
    // MARK: - 모델 타입 테스트
    
    func testWhisperModelType() {
        // 사용자 관점에서의 PUBLIC API 테스트
        let modelType = WhisperModelType.tiny
        
        // 공개 속성 테스트
        XCTAssertEqual(modelType.rawValue, "tiny")
        XCTAssertEqual(modelType.displayName, "Tiny")
        XCTAssertEqual(modelType.sizeInMB, 75)
        XCTAssertNotNil(modelType.githubReleaseURL)
        
        // 모든 케이스 테스트
        for type in WhisperModelType.allCases {
            XCTAssertFalse(type.displayName.isEmpty, "\(type.rawValue)의 displayName이 비어 있습니다")
            XCTAssertGreaterThan(type.sizeInMB, 0, "\(type.rawValue)의 sizeInMB가 0보다 작거나 같습니다")
            XCTAssertNotNil(type.githubReleaseURL, "\(type.rawValue)의 githubReleaseURL이 nil입니다")
        }
    }
    
    // MARK: - 트랜스크립션 세그먼트 테스트
    
    func testTranscriptionSegment() {
        // 사용자 관점에서의 PUBLIC API 테스트
        let segment = TranscriptionSegment(
            id: UUID(),
            index: 1,
            text: "안녕하세요",
            start: 0.0,
            end: 2.5,
            confidence: 0.95
        )
        
        // 공개 속성 테스트
        XCTAssertEqual(segment.index, 1)
        XCTAssertEqual(segment.text, "안녕하세요")
        XCTAssertEqual(segment.start, 0.0)
        XCTAssertEqual(segment.end, 2.5)
        XCTAssertEqual(segment.duration, 2.5)
        XCTAssertEqual(segment.confidence, 0.95)
        
        // 경계값 테스트
        let zeroLengthSegment = TranscriptionSegment(
            id: UUID(),
            index: 0,
            text: "",
            start: 10.0,
            end: 10.0,
            confidence: 1.0
        )
        XCTAssertEqual(zeroLengthSegment.duration, 0.0, "지속 시간이 0인 세그먼트의 duration이 올바르지 않습니다")
        
        // 음수 지속 시간 테스트 (비정상 케이스)
        let negativeSegment = TranscriptionSegment(
            id: UUID(),
            index: 2,
            text: "테스트",
            start: 5.0,
            end: 3.0,
            confidence: 0.8
        )
        XCTAssertEqual(negativeSegment.duration, -2.0, "음수 지속 시간이 올바르게 계산되지 않았습니다")
    }
    
    // MARK: - 트랜스크립션 결과 테스트
    
    func testTranscriptionResult() throws {
        // 테스트용 세그먼트 생성
        let segments = [
            TranscriptionSegment(
                id: UUID(),
                index: 0,
                text: "안녕하세요",
                start: 0.0,
                end: 2.5,
                confidence: 0.95
            ),
            TranscriptionSegment(
                id: UUID(),
                index: 1,
                text: "반갑습니다",
                start: 3.0,
                end: 5.0,
                confidence: 0.9
            )
        ]
        
        // 트랜스크립션 옵션 생성
        let options = TranscriptionOptions.default
        
        // 트랜스크립션 결과 생성
        let result = TranscriptionResult(
            segments: segments,
            detectedLanguage: "ko",
            options: options,
            processingTime: 1.5,
            audioDuration: 5.0
        )
        
        // 공개 속성 테스트
        XCTAssertEqual(result.segments.count, 2)
        XCTAssertEqual(result.detectedLanguage, "ko")
        XCTAssertEqual(result.processingTime, 1.5)
        XCTAssertEqual(result.audioDuration, 5.0)
        
        // 전체 텍스트 테스트
        XCTAssertEqual(result.text, "안녕하세요 반갑습니다")
    }
    
    // MARK: - 트랜스크립션 옵션 테스트
    
    func testTranscriptionOptions() {
        // 기본 옵션 테스트
        let defaultOptions = TranscriptionOptions.default
        XCTAssertNil(defaultOptions.language)
        
        // task 속성이 .transcribe인지 확인 (Equatable 대신 직접 비교)
        if case .transcribe = defaultOptions.task {
            // 테스트 통과
        } else {
            XCTFail("기본 옵션의 task가 .transcribe가 아닙니다")
        }
        
        // 사용자 정의 옵션 테스트
        let customOptions = TranscriptionOptions(
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
        
        XCTAssertEqual(customOptions.language, "ko")
        
        // task 속성이 .translate인지 확인 (Equatable 대신 직접 비교)
        if case .translate = customOptions.task {
            // 테스트 통과
        } else {
            XCTFail("사용자 정의 옵션의 task가 .translate가 아닙니다")
        }
        
        XCTAssertEqual(customOptions.temperature, 0.5)
        XCTAssertEqual(customOptions.compressionRatio, 2.0)
        XCTAssertEqual(customOptions.logProbThreshold, -0.5)
        XCTAssertEqual(customOptions.silenceThreshold, 0.7)
        XCTAssertEqual(customOptions.initialPrompt, "테스트")
        XCTAssertTrue(customOptions.enableWordTimestamps)
        XCTAssertEqual(customOptions.translationQuality, 0.8)
        XCTAssertTrue(customOptions.preserveFormats.contains(.numbers))
        XCTAssertTrue(customOptions.preserveFormats.contains(.names))
    }
    
    // MARK: - 단어 타임스탬프 테스트
    
    func testWordTimestamp() {
        // 단어 타임스탬프 생성
        let wordTimestamp = WordTimestamp(
            id: UUID(),
            word: "안녕",
            start: 1.0,
            end: 1.5,
            confidence: 0.9
        )
        
        // 공개 속성 테스트
        XCTAssertEqual(wordTimestamp.word, "안녕")
        XCTAssertEqual(wordTimestamp.start, 1.0)
        XCTAssertEqual(wordTimestamp.end, 1.5)
        XCTAssertEqual(wordTimestamp.confidence, 0.9)
    }
    
    // MARK: - 비동기 테스트 헬퍼
    
    @discardableResult
    func XCTUnwrapAsync<T>(
        _ expression: @autoclosure () async throws -> T,
        _ message: @autoclosure () -> String = "",
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws -> T {
        let evaluated = try? await expression()
        return try XCTUnwrap(evaluated, message(), file: file, line: line)
    }
    
    func XCTAssertNoThrowAsync<T>(
        _ expression: @autoclosure () async throws -> T,
        _ message: @autoclosure () -> String = "",
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            _ = try await expression()
        } catch {
            XCTFail(message(), file: file, line: line)
        }
    }
}
