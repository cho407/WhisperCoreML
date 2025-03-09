import Foundation

/// 에러 로깅을 위한 구조체
public struct ErrorLogger {
    /// 로그 레벨
    public enum LogLevel: Int, Comparable {
        case debug = 0
        case info = 1
        case warning = 2
        case error = 3
        case critical = 4
        
        public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }
    }
    
    /// 최소 로그 레벨
    private static var minimumLogLevel: LogLevel = .info
    
    /// 로그 레벨 설정
    public static func setLogLevel(_ level: LogLevel) {
        minimumLogLevel = level
    }
    
    /// 에러 로그 기록
    /// - Parameters:
    ///   - error: 발생한 에러
    ///   - level: 로그 레벨
    ///   - file: 발생 파일
    ///   - function: 발생 함수
    ///   - line: 발생 라인
    public static func log(
        _ error: WhisperError,
        level: LogLevel = .error,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        guard level >= minimumLogLevel else { return }
        
        let timestamp = Date()
        let filename = (file as NSString).lastPathComponent
        let message = """
        [\(formatLogLevel(level))] \(formatTimestamp(timestamp))
        File: \(filename)
        Function: \(function)
        Line: \(line)
        Error: \(error.localizedDescription)
        Reason: \(error.failureReason ?? "Unknown")
        Recovery: \(error.recoverySuggestion ?? "No suggestion")
        """
        
        // 로그 저장 (실제 구현에서는 파일이나 로깅 서비스에 저장)
        print(message)
    }
    
    /// 일반 메시지 로깅
    /// - Parameters:
    ///   - message: 로그 메시지
    ///   - level: 로그 레벨
    ///   - file: 발생 파일
    ///   - function: 발생 함수
    ///   - line: 발생 라인
    public static func log(
        _ message: String,
        level: LogLevel = .info,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        guard level >= minimumLogLevel else { return }
        
        let timestamp = Date()
        let filename = (file as NSString).lastPathComponent
        let formattedMessage = """
        [\(formatLogLevel(level))] \(formatTimestamp(timestamp))
        File: \(filename)
        Function: \(function)
        Line: \(line)
        Message: \(message)
        """
        
        print(formattedMessage)
    }
    
    private static func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter.string(from: date)
    }
    
    private static func formatLogLevel(_ level: LogLevel) -> String {
        switch level {
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .warning: return "WARNING"
        case .error: return "ERROR"
        case .critical: return "CRITICAL"
        }
    }
} 