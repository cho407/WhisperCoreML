//
//  MemoryLeakTests.swift
//  WhisperCoreMLUtils
//
//  Created by Hyunggu Cho
//

import XCTest
@testable import WhisperCoreMLUtils

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
    
    /// 자막 세그먼트 메모리 누수 테스트
    func testSubtitleSegmentMemoryLeak() {
        // 강한 참조 사이클이 없는지 확인
        let segment = SubtitleSegment(
            text: "안녕하세요",
            startTime: 1.0,
            endTime: 2.5
        )
        
        // 메모리 누수 추적
        trackForMemoryLeaks(on: segment as AnyObject)
    }
    
    /// 자막 생성 및 파싱 메모리 누수 테스트
    func testSubtitleGenerationMemoryLeak() throws {
        // 테스트용 세그먼트 생성
        let segments = [
            SubtitleSegment(text: "안녕하세요", startTime: 0.0, endTime: 2.5),
            SubtitleSegment(text: "반갑습니다", startTime: 3.0, endTime: 5.0)
        ]
        
        let subtitleUtils = SubtitleUtils.shared
        
        // 임시 파일 경로 생성
        let tempDir = FileManager.shared.temporaryDirectory()
        let srtURL = tempDir.appendingPathComponent("test_memory_leak.srt")
        
        // 파일 생성
        try subtitleUtils.createSRTFile(segments: segments, outputURL: srtURL)
        
        // 파일 파싱
        let parsedSegments = try subtitleUtils.parseSubtitleFile(at: srtURL)
        
        // 메모리 누수 추적
        for segment in parsedSegments {
            trackForMemoryLeaks(on: segment as AnyObject)
        }
        
        // 파일 삭제
        try? FileManager.default.removeItem(at: srtURL)
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