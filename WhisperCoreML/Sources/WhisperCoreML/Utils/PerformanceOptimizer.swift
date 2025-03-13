import Foundation
import CoreML

/// 성능 최적화 관리자
public class PerformanceOptimizer {
    /// 최적화 설정
    public struct Configuration {
        /// 기본 설정
        public static let `default` = Configuration()
        
        public init() {}
    }
    
    /// 설정
    private let configuration: Configuration
    
    /// 초기화
    /// - Parameter configuration: 최적화 설정
    public init(configuration: Configuration) {
        self.configuration = configuration
    }
    
    /// 최적의 연산 유닛 반환
    public func getOptimalComputeUnits() -> MLComputeUnits {
        #if targetEnvironment(simulator)
        return .cpuOnly
        #else
        return .all
        #endif
    }
    
    /// 최적화 제안 반환
    public func getOptimizationSuggestions() async -> [String] {
        var suggestions: [String] = []
        
        #if targetEnvironment(simulator)
        suggestions.append("시뮬레이터에서 실행 중입니다. 실제 기기에서 테스트하는 것을 권장합니다.")
        #endif
        
        return suggestions
    }
} 