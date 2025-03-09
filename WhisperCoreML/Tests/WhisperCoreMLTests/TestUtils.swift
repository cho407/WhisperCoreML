//
//  TestUtils.swift
//  WhisperCoreML
//
//  Created by Hyunggu Cho
//

import XCTest
import Foundation
@testable import WhisperCoreML

/// 테스트 유틸리티 클래스
class TestUtils {
    
    /// 테스트용 오디오 파일 생성
    /// - Parameters:
    ///   - duration: 오디오 길이 (초)
    ///   - sampleRate: 샘플 레이트
    /// - Returns: 오디오 파일 URL
    static func createTestAudioFile(duration: TimeInterval = 5.0, sampleRate: Double = 16000.0) -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let audioURL = tempDir.appendingPathComponent("test_audio_\(UUID().uuidString).wav")
        
        // 간단한 사인파 생성
        let totalSamples = Int(duration * sampleRate)
        var audioData = Data(capacity: totalSamples * 2) // 16비트 샘플
        
        for i in 0..<totalSamples {
            let time = Double(i) / sampleRate
            let amplitude: Double = 0.5
            let frequency: Double = 440.0 // A4 음
            
            // 사인파 생성
            let sample = Int16(amplitude * 32767.0 * sin(2.0 * .pi * frequency * time))
            
            // 리틀 엔디안으로 데이터 추가
            audioData.append(UInt8(truncatingIfNeeded: sample & 0xff))
            audioData.append(UInt8(truncatingIfNeeded: (sample >> 8) & 0xff))
        }
        
        // WAV 헤더 생성
        let headerSize = 44
        var header = Data(capacity: headerSize)
        
        // RIFF 청크
        header.append(contentsOf: "RIFF".utf8)
        let fileSize = UInt32(audioData.count + 36)
        header.append(UInt8(truncatingIfNeeded: fileSize & 0xff))
        header.append(UInt8(truncatingIfNeeded: (fileSize >> 8) & 0xff))
        header.append(UInt8(truncatingIfNeeded: (fileSize >> 16) & 0xff))
        header.append(UInt8(truncatingIfNeeded: (fileSize >> 24) & 0xff))
        header.append(contentsOf: "WAVE".utf8)
        
        // fmt 청크
        header.append(contentsOf: "fmt ".utf8)
        let fmtSize: UInt32 = 16
        header.append(UInt8(truncatingIfNeeded: fmtSize & 0xff))
        header.append(UInt8(truncatingIfNeeded: (fmtSize >> 8) & 0xff))
        header.append(UInt8(truncatingIfNeeded: (fmtSize >> 16) & 0xff))
        header.append(UInt8(truncatingIfNeeded: (fmtSize >> 24) & 0xff))
        
        let audioFormat: UInt16 = 1 // PCM
        header.append(UInt8(truncatingIfNeeded: audioFormat & 0xff))
        header.append(UInt8(truncatingIfNeeded: (audioFormat >> 8) & 0xff))
        
        let numChannels: UInt16 = 1 // 모노
        header.append(UInt8(truncatingIfNeeded: numChannels & 0xff))
        header.append(UInt8(truncatingIfNeeded: (numChannels >> 8) & 0xff))
        
        let sampleRateInt = UInt32(sampleRate)
        header.append(UInt8(truncatingIfNeeded: sampleRateInt & 0xff))
        header.append(UInt8(truncatingIfNeeded: (sampleRateInt >> 8) & 0xff))
        header.append(UInt8(truncatingIfNeeded: (sampleRateInt >> 16) & 0xff))
        header.append(UInt8(truncatingIfNeeded: (sampleRateInt >> 24) & 0xff))
        
        let byteRate = UInt32(sampleRate * Double(numChannels) * 2)
        header.append(UInt8(truncatingIfNeeded: byteRate & 0xff))
        header.append(UInt8(truncatingIfNeeded: (byteRate >> 8) & 0xff))
        header.append(UInt8(truncatingIfNeeded: (byteRate >> 16) & 0xff))
        header.append(UInt8(truncatingIfNeeded: (byteRate >> 24) & 0xff))
        
        let blockAlign: UInt16 = numChannels * 2
        header.append(UInt8(truncatingIfNeeded: blockAlign & 0xff))
        header.append(UInt8(truncatingIfNeeded: (blockAlign >> 8) & 0xff))
        
        let bitsPerSample: UInt16 = 16
        header.append(UInt8(truncatingIfNeeded: bitsPerSample & 0xff))
        header.append(UInt8(truncatingIfNeeded: (bitsPerSample >> 8) & 0xff))
        
        // 데이터 청크
        header.append(contentsOf: "data".utf8)
        let dataSize = UInt32(audioData.count)
        header.append(UInt8(truncatingIfNeeded: dataSize & 0xff))
        header.append(UInt8(truncatingIfNeeded: (dataSize >> 8) & 0xff))
        header.append(UInt8(truncatingIfNeeded: (dataSize >> 16) & 0xff))
        header.append(UInt8(truncatingIfNeeded: (dataSize >> 24) & 0xff))
        
        // 헤더와 오디오 데이터 결합
        var fileData = header
        fileData.append(audioData)
        
        // 파일 저장
        try? fileData.write(to: audioURL)
        
        return audioURL
    }
    
    /// 테스트용 세그먼트 생성
    /// - Returns: 테스트용 세그먼트 배열
    static func createTestSegments() -> [TranscriptionSegment] {
        return [
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
            ),
            TranscriptionSegment(
                id: UUID(),
                index: 2,
                text: "오늘은 날씨가 좋네요",
                start: 5.5,
                end: 8.0,
                confidence: 0.85
            )
        ]
    }
    
    /// 테스트용 단어 타임스탬프 생성
    /// - Returns: 테스트용 단어 타임스탬프 배열
    static func createTestWordTimestamps() -> [WordTimestamp] {
        return [
            WordTimestamp(
                id: UUID(),
                word: "안녕",
                start: 0.0,
                end: 1.0,
                confidence: 0.95
            ),
            WordTimestamp(
                id: UUID(),
                word: "하세요",
                start: 1.0,
                end: 2.5,
                confidence: 0.9
            )
        ]
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

/// 모의 오디오 프로세서
class MockAudioProcessor {
    var processAudioCalled = false
    var processedURL: URL?
    
    func processAudio(at url: URL) -> URL {
        processAudioCalled = true
        processedURL = url
        return url
    }
}

/// 모의 토크나이저
class MockTokenizer {
    var encodeCalled = false
    var decodeCalled = false
    var lastEncodedText: String?
    var lastDecodedTokens: [Int]?
    
    func encode(_ text: String) -> [Int] {
        encodeCalled = true
        lastEncodedText = text
        return [1, 2, 3, 4, 5] // 더미 토큰
    }
    
    func decode(_ tokens: [Int]) -> String {
        decodeCalled = true
        lastDecodedTokens = tokens
        return "디코딩된 텍스트"
    }
} 