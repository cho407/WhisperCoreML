// ModelConverter.swift
// Whisper 모델을 CoreML 형식으로 변환하는 유틸리티

import Foundation
import Combine

/// 모델 변환 상태
public enum ModelConversionState: Equatable {
    case notStarted
    case downloading(progress: Double)
    case converting(progress: Double)
    case completed(modelURL: URL)
    case failed(error: String)
    
    public static func == (lhs: ModelConversionState, rhs: ModelConversionState) -> Bool {
        switch (lhs, rhs) {
        case (.notStarted, .notStarted):
            return true
        case (.downloading(let lhsProgress), .downloading(let rhsProgress)):
            return lhsProgress == rhsProgress
        case (.converting(let lhsProgress), .converting(let rhsProgress)):
            return lhsProgress == rhsProgress
        case (.completed(let lhsURL), .completed(let rhsURL)):
            return lhsURL == rhsURL
        case (.failed(let lhsError), .failed(let rhsError)):
            return lhsError == rhsError
        default:
            return false
        }
    }
}

/// 모델 변환 옵션
public struct ModelConversionOptions {
    public let computeUnits: ComputeUnits
    public let optimizationOptions: OptimizationOptions
    
    public init(computeUnits: ComputeUnits = .all, optimizationOptions: OptimizationOptions = .default) {
        self.computeUnits = computeUnits
        self.optimizationOptions = optimizationOptions
    }
    
    public static let `default` = ModelConversionOptions()
}

/// 컴퓨팅 유닛 옵션
public enum ComputeUnits: String, CaseIterable {
    case cpuOnly = "CPU_ONLY"
    case cpuAndGPU = "CPU_AND_GPU"
    case all = "ALL"
    
    public var displayName: String {
        switch self {
        case .cpuOnly: return "CPU만 사용"
        case .cpuAndGPU: return "CPU 및 GPU 사용"
        case .all: return "모든 장치 사용"
        }
    }
}

/// 최적화 옵션
public struct OptimizationOptions {
    public let quantize: Bool
    public let reduceMemory: Bool
    public let useMetalPerformanceShaders: Bool
    
    public init(quantize: Bool = true, reduceMemory: Bool = true, useMetalPerformanceShaders: Bool = true) {
        self.quantize = quantize
        self.reduceMemory = reduceMemory
        self.useMetalPerformanceShaders = useMetalPerformanceShaders
    }
    
    public static let `default` = OptimizationOptions()
}

/// 모델 변환기
public class ModelConverter {
    /// 싱글톤 인스턴스
    public static let shared = ModelConverter()
    
    /// 변환 상태 Subject
    private let conversionStateSubject = CurrentValueSubject<ModelConversionState, Never>(.notStarted)
    
    /// 변환 상태 Publisher
    public var conversionState: AnyPublisher<ModelConversionState, Never> {
        conversionStateSubject.eraseToAnyPublisher()
    }
    
    /// 초기화
    private init() {}
    
    /// 모델 변환 시작
    public func convertModel(modelURL: URL, outputURL: URL, options: ModelConversionOptions = .default) {
        conversionStateSubject.send(.notStarted)
        
        // 실제 구현에서는 Python 스크립트를 실행하거나 다른 방법으로 모델 변환을 수행합니다.
        // 이 예제에서는 변환 과정을 시뮬레이션합니다.
        
        // 다운로드 시뮬레이션
        simulateDownload()
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.conversionStateSubject.send(.failed(error: error.localizedDescription))
                }
            }, receiveValue: { [weak self] progress in
                self?.conversionStateSubject.send(.downloading(progress: progress))
                
                // 다운로드 완료 시 변환 시작
                if progress >= 1.0 {
                    self?.simulateConversion(outputURL: outputURL)
                        .sink(receiveCompletion: { completion in
                            if case .failure(let error) = completion {
                                self?.conversionStateSubject.send(.failed(error: error.localizedDescription))
                            }
                        }, receiveValue: { progress in
                            self?.conversionStateSubject.send(.converting(progress: progress))
                            
                            // 변환 완료
                            if progress >= 1.0 {
                                self?.conversionStateSubject.send(.completed(modelURL: outputURL))
                            }
                        })
                        .store(in: &self!.cancellables)
                }
            })
            .store(in: &cancellables)
    }
    
    /// 다운로드 시뮬레이션
    private func simulateDownload() -> AnyPublisher<Double, Error> {
        return Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .scan(0.0) { progress, _ in
                return min(progress + 0.1, 1.0)
            }
            .map { $0 }
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    /// 변환 시뮬레이션
    private func simulateConversion(outputURL: URL) -> AnyPublisher<Double, Error> {
        return Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .scan(0.0) { progress, _ in
                return min(progress + 0.1, 1.0)
            }
            .map { $0 }
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    /// 취소 저장소
    private var cancellables = Set<AnyCancellable>()
    
    /// 변환 취소
    public func cancelConversion() {
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
        conversionStateSubject.send(.notStarted)
    }
    
    /// 모델 변환 (async/await)
    public func convertModelAsync(modelURL: URL, outputURL: URL, options: ModelConversionOptions = .default) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            var stateCancellable: AnyCancellable?
            
            stateCancellable = conversionState.sink { state in
                switch state {
                case .completed(let url):
                    stateCancellable?.cancel()
                    continuation.resume(returning: url)
                case .failed(let error):
                    stateCancellable?.cancel()
                    continuation.resume(throwing: NSError(domain: "ModelConverter", code: -1, userInfo: [NSLocalizedDescriptionKey: error]))
                default:
                    break
                }
            }
            
            convertModel(modelURL: modelURL, outputURL: outputURL, options: options)
        }
    }
} 