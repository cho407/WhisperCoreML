//
//  TestUtils.swift
//  WhisperCoreMLUtils
//
//  Created by Hyunggu Cho
//

import XCTest
import Foundation
@testable import WhisperCoreMLUtils

/// 테스트 유틸리티 클래스
class TestUtils {
    
    /// 테스트용 임시 파일 생성
    /// - Parameters:
    ///   - content: 파일 내용
    ///   - extension: 파일 확장자
    /// - Returns: 임시 파일 URL
    static func createTempFile(content: String, extension: String) -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("test_file_\(UUID().uuidString).\(`extension`)")
        
        try? content.write(to: fileURL, atomically: true, encoding: .utf8)
        
        return fileURL
    }
    
    /// 테스트용 자막 세그먼트 생성
    /// - Returns: 테스트용 자막 세그먼트 배열
    static func createTestSubtitleSegments() -> [SubtitleSegment] {
        return [
            SubtitleSegment(text: "안녕하세요", startTime: 0.0, endTime: 2.5),
            SubtitleSegment(text: "반갑습니다", startTime: 3.0, endTime: 5.0),
            SubtitleSegment(text: "오늘은 날씨가 좋네요", startTime: 5.5, endTime: 8.0)
        ]
    }
    
    /// 테스트용 SRT 문자열 생성
    /// - Returns: SRT 형식의 문자열
    static func createTestSRTString() -> String {
        return """
        1
        00:00:00,000 --> 00:00:02,500
        안녕하세요
        
        2
        00:00:03,000 --> 00:00:05,000
        반갑습니다
        
        3
        00:00:05,500 --> 00:00:08,000
        오늘은 날씨가 좋네요
        
        """
    }
    
    /// 테스트용 VTT 문자열 생성
    /// - Returns: VTT 형식의 문자열
    static func createTestVTTString() -> String {
        return """
        WEBVTT
        
        1
        00:00:00.000 --> 00:00:02.500
        안녕하세요
        
        2
        00:00:03.000 --> 00:00:05.000
        반갑습니다
        
        3
        00:00:05.500 --> 00:00:08.000
        오늘은 날씨가 좋네요
        
        """
    }
    
    /// 테스트 완료 후 파일 정리
    /// - Parameter url: 삭제할 파일 URL
    static func cleanupFile(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
    
    /// 비동기 테스트 헬퍼
    /// - Parameters:
    ///   - timeout: 타임아웃 시간 (초)
    ///   - testBlock: 테스트 블록
    static func runAsyncTest(timeout: TimeInterval = 5.0, testBlock: @escaping () async throws -> Void) {
        let expectation = XCTestExpectation(description: "Async test")
        
        Task {
            do {
                try await testBlock()
                expectation.fulfill()
            } catch {
                XCTFail("비동기 테스트 실패: \(error)")
                expectation.fulfill()
            }
        }
        
        XCTWaiter().wait(for: [expectation], timeout: timeout)
    }
}

/// XCTestCase 확장 - 메모리 누수 추적
extension XCTestCase {
    /// 메모리 누수 추적
    /// - Parameters:
    ///   - instance: 추적할 객체
    ///   - file: 파일 경로
    ///   - line: 라인 번호
    func trackForMemoryLeaks(on instance: AnyObject, file: StaticString = #filePath, line: UInt = #line) {
        addTeardownBlock { [weak instance] in
            XCTAssertNil(instance, "메모리 누수가 감지되었습니다", file: file, line: line)
        }
    }
} 