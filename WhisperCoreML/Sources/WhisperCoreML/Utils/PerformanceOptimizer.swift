import Foundation
import CoreML

/// 성능 최적화 관리자
public class PerformanceOptimizer {
    /// 설정
    public struct Configuration {
        public let enableNeuralEngine: Bool
        public let enableGPU: Bool
        public let enableLowPrecision: Bool
        
        public static let `default` = Configuration(
            enableNeuralEngine: true,
            enableGPU: true,
            enableLowPrecision: true
        )
    }
    
    private let configuration: Configuration
    
    public init(configuration: Configuration) {
        self.configuration = configuration
    }
    
    @available(macOS 12.0, iOS 15.0, *)
    public func recommendedComputeUnits() async -> MLComputeUnits {
        if configuration.enableNeuralEngine {
            if #available(macOS 13.0, iOS 16.0, *) {
                return .cpuAndNeuralEngine
            }
        }
        return configuration.enableGPU ? .cpuAndGPU : .cpuOnly
    }
    
    public func getOptimizationSuggestions() async -> [String] {
        var suggestions: [String] = []
        
        if !configuration.enableNeuralEngine {
            suggestions.append("Neural Engine을 활성화하여 성능을 향상시킬 수 있습니다.")
        }
        
        if !configuration.enableGPU {
            suggestions.append("GPU를 활성화하여 성능을 향상시킬 수 있습니다.")
        }
        
        if !configuration.enableLowPrecision {
            suggestions.append("저정밀도 연산을 활성화하여 메모리 사용량을 줄일 수 있습니다.")
        }
        
        return suggestions
    }
} 