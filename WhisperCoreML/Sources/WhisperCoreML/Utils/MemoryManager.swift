import Foundation

#if os(iOS) || os(tvOS) || os(watchOS)
import UIKit
#endif

/// 메모리 관리자
public struct MemoryManager {
    /// 메모리 사용량 경고 임계값 (기본값: 500MB)
    public static let memoryWarningThreshold: UInt64 = 500 * 1024 * 1024
    
    /// 현재 메모리 사용량 확인
    public static func currentMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return info.resident_size
        } else {
            return 0
        }
    }
    
    /// 메모리 제약 상태 확인
    public static func isMemoryConstrained() -> Bool {
        return currentMemoryUsage() > memoryWarningThreshold
    }
    
    /// 사용 가능한 메모리 확인
    public static func availableMemory() -> UInt64 {
        #if os(iOS) || os(tvOS) || os(watchOS)
        // iOS에서는 정확한 사용 가능 메모리를 얻기 어려움
        // 대략적인 추정값 반환
        let usedMemory = currentMemoryUsage()
        let totalMemoryGuess: UInt64 = 2 * 1024 * 1024 * 1024 // 2GB로 가정
        return totalMemoryGuess > usedMemory ? totalMemoryGuess - usedMemory : 0
        #elseif os(macOS)
        var stats = vm_statistics64_data_t()
        var size = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &size)
            }
        }
        
        if result == KERN_SUCCESS {
            let pageSize = UInt64(vm_kernel_page_size)
            return UInt64(stats.free_count) * pageSize
        }
        return 0
        #else
        return 0
        #endif
    }
    
    /// 메모리 경고 등록
    #if os(iOS) || os(tvOS) || os(watchOS)
    public static func registerMemoryWarningNotification(handler: @escaping () -> Void) {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { _ in
            handler()
        }
    }
    #endif
    
    /// 메모리 정리 요청
    public static func requestMemoryRelease() {
        #if os(iOS) || os(tvOS) || os(watchOS)
        // iOS에서는 시스템에 메모리 해제 힌트 제공
        UIApplication.shared.performSelector(inBackground: #selector(URLCache.shared.removeAllCachedResponses), with: nil)
        #endif
        
        // 가비지 컬렉션 힌트
        autoreleasepool {
            // 임시 객체 정리
        }
    }
} 