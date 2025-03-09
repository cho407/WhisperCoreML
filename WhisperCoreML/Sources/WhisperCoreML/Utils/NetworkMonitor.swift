import Foundation
#if canImport(Network)
import Network
#endif

/// 네트워크 상태
public enum NetworkStatus {
    /// 연결됨
    case connected(ConnectionType)
    /// 연결 끊김
    case disconnected
    
    /// 연결 여부
    public var isConnected: Bool {
        switch self {
        case .connected: return true
        case .disconnected: return false
        }
    }
}

/// 연결 타입
public enum ConnectionType {
    /// Wi-Fi
    case wifi
    /// 셀룰러
    case cellular
    /// 유선
    case wired
    /// 알 수 없음
    case unknown
}

/// 네트워크 모니터
public struct NetworkMonitor {
    #if canImport(Network)
    private static let monitor = NWPathMonitor()
    private static var isMonitorStarted = false
    private static var currentStatus: NetworkStatus = .disconnected
    
    /// 모니터 시작
    public static func startMonitorIfNeeded() {
        guard !isMonitorStarted else { return }
        
        monitor.pathUpdateHandler = { path in
            if path.status == .satisfied {
                if path.usesInterfaceType(.wifi) {
                    currentStatus = .connected(.wifi)
                } else if path.usesInterfaceType(.cellular) {
                    currentStatus = .connected(.cellular)
                } else if path.usesInterfaceType(.wiredEthernet) {
                    currentStatus = .connected(.wired)
                } else {
                    currentStatus = .connected(.unknown)
                }
            } else {
                currentStatus = .disconnected
            }
        }
        
        let queue = DispatchQueue(label: "NetworkMonitor")
        monitor.start(queue: queue)
        isMonitorStarted = true
    }
    #endif
    
    /// 현재 네트워크 상태 확인
    public static func checkCurrentStatus() -> NetworkStatus {
        #if canImport(Network)
        startMonitorIfNeeded()
        return currentStatus
        #else
        // 네트워크 모니터링을 지원하지 않는 플랫폼에서는 기본적으로 연결됨으로 가정
        return .connected(.unknown)
        #endif
    }
    
    /// 네트워크 연결 여부 확인
    public static func isNetworkAvailable() -> Bool {
        return checkCurrentStatus().isConnected
    }
} 