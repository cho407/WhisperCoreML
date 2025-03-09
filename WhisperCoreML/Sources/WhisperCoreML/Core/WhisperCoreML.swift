// The Swift Programming Language
// https://docs.swift.org/swift-book

// WhisperCoreML
// 오픈소스 Whisper AI 모델을 CoreML로 변환하여 사용하는 라이브러리

import Foundation
import CoreML
import AVFoundation
import Combine

/// WhisperCoreML의 메인 클래스
public class WhisperTranscriber {
    /// 싱글톤 인스턴스
    public static let shared = WhisperTranscriber()
    
    /// 현재 사용 중인 모델
    private var currentModel: WhisperModel?
    
    /// 모델 다운로드 상태를 추적하는 Subject
    private let downloadProgressSubject = PassthroughSubject<BasicModelDownloadProgress, Never>()
    
    /// 초기화 메서드
    private init() {}
    
    /// 모델 로드
    /// - Parameter modelType: 모델 타입
    /// - Returns: 성공 여부
    @discardableResult
    public func loadModel(modelType: WhisperModelType) async -> Bool {
        do {
            let model = try WhisperModel(modelType: modelType)
            try await model.loadModel()
            self.currentModel = model
            return true
        } catch {
            print("모델 로드 실패: \(error)")
            return false
        }
    }
}

/// 기본 모델 다운로드 진행 상황
public struct BasicModelDownloadProgress {
    public let modelType: WhisperModelType
    public let bytesDownloaded: UInt64
    public let totalBytes: UInt64
    public let percentage: Double
    
    init(modelType: WhisperModelType, bytesDownloaded: UInt64, totalBytes: UInt64) {
        self.modelType = modelType
        self.bytesDownloaded = bytesDownloaded
        self.totalBytes = totalBytes
        self.percentage = totalBytes > 0 ? Double(bytesDownloaded) / Double(totalBytes) * 100.0 : 0
    }
    
    init(modelType: WhisperModelType, bytesDownloaded: Int64, totalBytes: Int64) {
        self.init(
            modelType: modelType,
            bytesDownloaded: bytesDownloaded >= 0 ? UInt64(bytesDownloaded) : 0,
            totalBytes: totalBytes >= 0 ? UInt64(totalBytes) : 0
        )
    }
}
