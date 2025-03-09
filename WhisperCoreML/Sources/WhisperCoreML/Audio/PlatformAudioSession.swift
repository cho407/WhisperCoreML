import Foundation
import AVFoundation

/// 플랫폼별 오디오 세션 프로토콜
protocol AudioSessionProtocol {
    func setup() throws
}

#if os(iOS)
/// iOS 오디오 세션
class iOSAudioSession: AudioSessionProtocol {
    func setup() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }
}
#elseif os(macOS)
/// macOS 오디오 세션
class macOSAudioSession: AudioSessionProtocol {
    func setup() throws {
        // macOS에서는 별도의 오디오 세션 설정이 필요 없음
    }
}
#endif

/// 오디오 세션 팩토리
enum AudioSessionFactory {
    static func createAudioSession() -> AudioSessionProtocol {
        #if os(iOS)
        return iOSAudioSession()
        #elseif os(macOS)
        return macOSAudioSession()
        #else
        fatalError("Unsupported platform")
        #endif
    }
} 