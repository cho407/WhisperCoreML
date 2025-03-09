//
//  WhisperCoreMLUtilsTests.swift
//  WhisperCoreML
//
//  Created by Hyunggu Cho
//

import XCTest
@testable import WhisperCoreMLUtils

final class WhisperCoreMLUtilsTests: XCTestCase {
    
    // MARK: - 테스트 설정 및 해제
    
    override func setUpWithError() throws {
        // 각 테스트 메서드 실행 전 설정 코드
    }
    
    override func tearDownWithError() throws {
        // 각 테스트 메서드 실행 후 정리 코드
    }
    
    // MARK: - 파일 관리자 테스트
    
    func testFileManager() {
        // 사용자 관점에서의 PUBLIC API 테스트
        let fileManager = FileManager.shared
        
        // 공개 메서드 테스트
        let tempDir = fileManager.temporaryDirectory()
        XCTAssertFalse(tempDir.path.isEmpty)
        
        let documentsDir = fileManager.documentsDirectory()
        XCTAssertFalse(documentsDir.path.isEmpty)
        
        // 디렉토리 존재 여부 테스트
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempDir.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: documentsDir.path))
        
        // 캐시 디렉토리 테스트
        let cacheDir = fileManager.cacheDirectory()
        XCTAssertFalse(cacheDir.path.isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: cacheDir.path))
        
        // 애플리케이션 지원 디렉토리 테스트
        let appSupportDir = fileManager.applicationSupportDirectory()
        XCTAssertFalse(appSupportDir.path.isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: appSupportDir.path))
    }
    
    func testFileManagerFileOperations() {
        // 사용자 관점에서의 PUBLIC API 테스트
        let fileManager = FileManager.shared
        
        // 임시 디렉토리에 테스트 파일 생성
        let tempDir = fileManager.temporaryDirectory()
        let testFileURL = tempDir.appendingPathComponent("test_file.txt")
        
        // 파일 존재 여부 확인 (생성 전)
        XCTAssertFalse(fileManager.fileExists(at: testFileURL))
        
        // 테스트 파일 생성
        let testContent = "테스트 내용"
        try? testContent.write(to: testFileURL, atomically: true, encoding: .utf8)
        
        // 파일 존재 여부 확인 (생성 후)
        XCTAssertTrue(fileManager.fileExists(at: testFileURL))
        
        // 파일 크기 확인
        do {
            let fileSize = try fileManager.fileSize(at: testFileURL)
            XCTAssertGreaterThan(fileSize, 0)
        } catch {
            XCTFail("파일 크기 확인 실패: \(error)")
        }
        
        // 파일 삭제
        do {
            try fileManager.deleteFile(at: testFileURL)
            XCTAssertFalse(fileManager.fileExists(at: testFileURL))
        } catch {
            XCTFail("파일 삭제 실패: \(error)")
        }
    }
    
    // MARK: - 자막 유틸리티 테스트
    
    func testSubtitleUtils() {
        // 사용자 관점에서의 PUBLIC API 테스트
        let subtitleUtils = SubtitleUtils.shared
        
        // 시간 포맷팅 테스트 (1시간 1분 1.5초)
        let timeInSeconds: TimeInterval = 3661.5
        
        // SRT 시간 포맷팅
        let srtTime = subtitleUtils.formatSRTTime(timeInSeconds)
        XCTAssertEqual(srtTime, "01:01:01,500")
        
        // VTT 시간 포맷팅
        let vttTime = subtitleUtils.formatVTTTime(timeInSeconds)
        XCTAssertEqual(vttTime, "01:01:01.500")
        
        // 경계값 테스트
        XCTAssertEqual(subtitleUtils.formatSRTTime(0), "00:00:00,000")
        XCTAssertEqual(subtitleUtils.formatVTTTime(0), "00:00:00.000")
        
        // 큰 값 테스트
        let largeTime: TimeInterval = 36000 + 3600 + 60 + 1.5 // 11:01:01.500
        XCTAssertEqual(subtitleUtils.formatSRTTime(largeTime), "11:01:01,500")
        XCTAssertEqual(subtitleUtils.formatVTTTime(largeTime), "11:01:01.500")
    }
    
    func testSubtitleSegment() {
        // 자막 세그먼트 생성
        let segment = SubtitleSegment(
            text: "안녕하세요",
            startTime: 1.0,
            endTime: 2.5
        )
        
        // 공개 속성 테스트
        XCTAssertEqual(segment.text, "안녕하세요")
        XCTAssertEqual(segment.startTime, 1.0)
        XCTAssertEqual(segment.endTime, 2.5)
        
        // ID 고유성 테스트
        let segment2 = SubtitleSegment(
            text: "안녕하세요",
            startTime: 1.0,
            endTime: 2.5
        )
        XCTAssertNotEqual(segment.id, segment2.id)
    }
    
    func testSubtitleGeneration() throws {
        // 테스트용 세그먼트 생성
        let segments = [
            SubtitleSegment(text: "안녕하세요", startTime: 0.0, endTime: 2.5),
            SubtitleSegment(text: "반갑습니다", startTime: 3.0, endTime: 5.0)
        ]
        
        let subtitleUtils = SubtitleUtils.shared
        
        // SRT 문자열 생성 테스트
        let srtContent = subtitleUtils.createSRTString(segments: segments)
        XCTAssertTrue(srtContent.contains("1\n00:00:00,000 --> 00:00:02,500\n안녕하세요"))
        XCTAssertTrue(srtContent.contains("2\n00:00:03,000 --> 00:00:05,000\n반갑습니다"))
        
        // VTT 문자열 생성 테스트
        let vttContent = subtitleUtils.createVTTString(segments: segments)
        XCTAssertTrue(vttContent.contains("WEBVTT"))
        XCTAssertTrue(vttContent.contains("1\n00:00:00.000 --> 00:00:02.500\n안녕하세요"))
        XCTAssertTrue(vttContent.contains("2\n00:00:03.000 --> 00:00:05.000\n반갑습니다"))
        
        // 임시 파일 경로 생성
        let tempDir = FileManager.shared.temporaryDirectory()
        let srtURL = tempDir.appendingPathComponent("test.srt")
        let vttURL = tempDir.appendingPathComponent("test.vtt")
        
        // 파일 생성 테스트
        do {
            try subtitleUtils.createSRTFile(segments: segments, outputURL: srtURL)
            try subtitleUtils.createVTTFile(segments: segments, outputURL: vttURL)
            
            // 파일 존재 확인
            XCTAssertTrue(FileManager.default.fileExists(atPath: srtURL.path))
            XCTAssertTrue(FileManager.default.fileExists(atPath: vttURL.path))
            
            // 파일 내용 확인
            let srtFileContent = try String(contentsOf: srtURL, encoding: .utf8)
            let vttFileContent = try String(contentsOf: vttURL, encoding: .utf8)
            
            XCTAssertTrue(srtFileContent.contains("1\n00:00:00,000 --> 00:00:02,500\n안녕하세요"))
            XCTAssertTrue(vttFileContent.contains("WEBVTT"))
            
            // 파일 삭제
            try FileManager.default.removeItem(at: srtURL)
            try FileManager.default.removeItem(at: vttURL)
        } catch {
            XCTFail("자막 파일 생성 실패: \(error)")
        }
    }
    
    func testSubtitleParsing() throws {
        // 테스트용 세그먼트 생성
        let segments = [
            SubtitleSegment(text: "안녕하세요", startTime: 0.0, endTime: 2.5),
            SubtitleSegment(text: "반갑습니다", startTime: 3.0, endTime: 5.0)
        ]
        
        let subtitleUtils = SubtitleUtils.shared
        
        // 임시 파일 경로 생성
        let tempDir = FileManager.shared.temporaryDirectory()
        let srtURL = tempDir.appendingPathComponent("test_parse.srt")
        let vttURL = tempDir.appendingPathComponent("test_parse.vtt")
        
        // 파일 생성
        try subtitleUtils.createSRTFile(segments: segments, outputURL: srtURL)
        try subtitleUtils.createVTTFile(segments: segments, outputURL: vttURL)
        
        // SRT 파일 파싱 테스트
        do {
            let parsedSegments = try subtitleUtils.parseSubtitleFile(at: srtURL)
            XCTAssertEqual(parsedSegments.count, 2)
            XCTAssertEqual(parsedSegments[0].text, "안녕하세요")
            XCTAssertEqual(parsedSegments[0].startTime, 0.0, accuracy: 0.001)
            XCTAssertEqual(parsedSegments[0].endTime, 2.5, accuracy: 0.001)
            
            // 파일 삭제
            try FileManager.default.removeItem(at: srtURL)
            try FileManager.default.removeItem(at: vttURL)
        } catch {
            XCTFail("자막 파일 파싱 실패: \(error)")
            
            // 파일 삭제 시도
            try? FileManager.default.removeItem(at: srtURL)
            try? FileManager.default.removeItem(at: vttURL)
        }
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
