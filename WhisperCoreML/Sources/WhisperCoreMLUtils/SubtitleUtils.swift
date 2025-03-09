import Foundation

/// 자막 세그먼트 구조체
public struct SubtitleSegment: Identifiable, Codable, Equatable {
    /// 고유 식별자
    public let id: UUID
    
    /// 자막 텍스트
    public let text: String
    
    /// 시작 시간 (초)
    public let startTime: TimeInterval
    
    /// 종료 시간 (초)
    public let endTime: TimeInterval
    
    /// 초기화 메서드
    public init(
        id: UUID = UUID(),
        text: String,
        startTime: TimeInterval,
        endTime: TimeInterval
    ) {
        self.id = id
        self.text = text
        self.startTime = startTime
        self.endTime = endTime
    }
}

/// 자막 유틸리티 클래스
public class SubtitleUtils {
    /// 공유 인스턴스
    public static let shared = SubtitleUtils()
    
    /// 초기화 메서드
    private init() {}
    
    /// SRT 형식으로 시간 포맷팅
    /// - Parameter time: 시간 (초)
    /// - Returns: "00:00:00,000" 형식의 문자열
    public func formatSRTTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time - floor(time)) * 1000)
        
        return String(format: "%02d:%02d:%02d,%03d", hours, minutes, seconds, milliseconds)
    }
    
    /// VTT 형식으로 시간 포맷팅
    /// - Parameter time: 시간 (초)
    /// - Returns: "00:00:00.000" 형식의 문자열
    public func formatVTTTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time - floor(time)) * 1000)
        
        return String(format: "%02d:%02d:%02d.%03d", hours, minutes, seconds, milliseconds)
    }
    
    /// SRT 파일 생성
    /// - Parameters:
    ///   - segments: 자막 세그먼트 배열
    ///   - outputURL: 출력 파일 URL
    public func createSRTFile(segments: [SubtitleSegment], outputURL: URL) throws {
        let srtString = createSRTString(segments: segments)
        try srtString.write(to: outputURL, atomically: true, encoding: .utf8)
    }
    
    /// SRT 문자열 생성
    /// - Parameter segments: 자막 세그먼트 배열
    /// - Returns: SRT 형식의 문자열
    public func createSRTString(segments: [SubtitleSegment]) -> String {
        var srtString = ""
        
        for (index, segment) in segments.enumerated() {
            let startTime = formatSRTTime(segment.startTime)
            let endTime = formatSRTTime(segment.endTime)
            
            srtString += "\(index + 1)\n"
            srtString += "\(startTime) --> \(endTime)\n"
            srtString += "\(segment.text)\n\n"
        }
        
        return srtString
    }
    
    /// VTT 파일 생성
    /// - Parameters:
    ///   - segments: 자막 세그먼트 배열
    ///   - outputURL: 출력 파일 URL
    public func createVTTFile(segments: [SubtitleSegment], outputURL: URL) throws {
        let vttString = createVTTString(segments: segments)
        try vttString.write(to: outputURL, atomically: true, encoding: .utf8)
    }
    
    /// VTT 문자열 생성
    /// - Parameter segments: 자막 세그먼트 배열
    /// - Returns: VTT 형식의 문자열
    public func createVTTString(segments: [SubtitleSegment]) -> String {
        var vttString = "WEBVTT\n\n"
        
        for (index, segment) in segments.enumerated() {
            let startTime = formatVTTTime(segment.startTime)
            let endTime = formatVTTTime(segment.endTime)
            
            vttString += "\(index + 1)\n"
            vttString += "\(startTime) --> \(endTime)\n"
            vttString += "\(segment.text)\n\n"
        }
        
        return vttString
    }
    
    /// 자막 파일 파싱
    /// - Parameter url: 자막 파일 URL
    /// - Returns: 자막 세그먼트 배열
    public func parseSubtitleFile(at url: URL) throws -> [SubtitleSegment] {
        let fileExtension = url.pathExtension.lowercased()
        let fileContents = try String(contentsOf: url, encoding: .utf8)
        
        switch fileExtension {
        case "srt":
            return try parseSRT(fileContents)
        case "vtt":
            return try parseVTT(fileContents)
        default:
            throw NSError(domain: "SubtitleUtils", code: 1, userInfo: [NSLocalizedDescriptionKey: "지원되지 않는 자막 형식입니다."])
        }
    }
    
    /// SRT 파일 파싱
    /// - Parameter content: SRT 파일 내용
    /// - Returns: 자막 세그먼트 배열
    private func parseSRT(_ content: String) throws -> [SubtitleSegment] {
        var segments = [SubtitleSegment]()
        let pattern = "\\d+\\s+(\\d{2}:\\d{2}:\\d{2},\\d{3})\\s+-->\\s+(\\d{2}:\\d{2}:\\d{2},\\d{3})\\s+([\\s\\S]*?)(?=\\n\\d+\\s+\\d{2}:\\d{2}:\\d{2},\\d{3}|$)"
        
        let regex = try NSRegularExpression(pattern: pattern, options: [])
        let matches = regex.matches(in: content, options: [], range: NSRange(location: 0, length: content.utf16.count))
        
        for match in matches {
            if let startTimeRange = Range(match.range(at: 1), in: content),
               let endTimeRange = Range(match.range(at: 2), in: content),
               let textRange = Range(match.range(at: 3), in: content) {
                
                let startTimeString = String(content[startTimeRange])
                let endTimeString = String(content[endTimeRange])
                let text = String(content[textRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                
                if let startTime = parseSRTTime(startTimeString),
                   let endTime = parseSRTTime(endTimeString) {
                    
                    let segment = SubtitleSegment(
                        text: text,
                        startTime: startTime,
                        endTime: endTime
                    )
                    
                    segments.append(segment)
                }
            }
        }
        
        return segments
    }
    
    /// VTT 파일 파싱
    /// - Parameter content: VTT 파일 내용
    /// - Returns: 자막 세그먼트 배열
    private func parseVTT(_ content: String) throws -> [SubtitleSegment] {
        var segments = [SubtitleSegment]()
        
        // WEBVTT 헤더 제거
        let contentWithoutHeader = content.replacingOccurrences(of: "WEBVTT\n", with: "")
        
        let pattern = "\\d+\\s+(\\d{2}:\\d{2}:\\d{2}\\.\\d{3})\\s+-->\\s+(\\d{2}:\\d{2}:\\d{2}\\.\\d{3})\\s+([\\s\\S]*?)(?=\\n\\d+\\s+\\d{2}:\\d{2}:\\d{2}\\.\\d{3}|$)"
        
        let regex = try NSRegularExpression(pattern: pattern, options: [])
        let matches = regex.matches(in: contentWithoutHeader, options: [], range: NSRange(location: 0, length: contentWithoutHeader.utf16.count))
        
        for match in matches {
            if let startTimeRange = Range(match.range(at: 1), in: contentWithoutHeader),
               let endTimeRange = Range(match.range(at: 2), in: contentWithoutHeader),
               let textRange = Range(match.range(at: 3), in: contentWithoutHeader) {
                
                let startTimeString = String(contentWithoutHeader[startTimeRange])
                let endTimeString = String(contentWithoutHeader[endTimeRange])
                let text = String(contentWithoutHeader[textRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                
                if let startTime = parseVTTTime(startTimeString),
                   let endTime = parseVTTTime(endTimeString) {
                    
                    let segment = SubtitleSegment(
                        text: text,
                        startTime: startTime,
                        endTime: endTime
                    )
                    
                    segments.append(segment)
                }
            }
        }
        
        return segments
    }
    
    /// SRT 시간 문자열 파싱
    /// - Parameter timeString: "00:00:00,000" 형식의 문자열
    /// - Returns: 시간 (초)
    private func parseSRTTime(_ timeString: String) -> TimeInterval? {
        let components = timeString.components(separatedBy: CharacterSet(charactersIn: ":,"))
        
        guard components.count == 4,
              let hours = Int(components[0]),
              let minutes = Int(components[1]),
              let seconds = Int(components[2]),
              let milliseconds = Int(components[3]) else {
            return nil
        }
        
        return TimeInterval(hours * 3600 + minutes * 60 + seconds) + TimeInterval(milliseconds) / 1000.0
    }
    
    /// VTT 시간 문자열 파싱
    /// - Parameter timeString: "00:00:00.000" 형식의 문자열
    /// - Returns: 시간 (초)
    private func parseVTTTime(_ timeString: String) -> TimeInterval? {
        let components = timeString.components(separatedBy: CharacterSet(charactersIn: ":."))
        
        guard components.count == 4,
              let hours = Int(components[0]),
              let minutes = Int(components[1]),
              let seconds = Int(components[2]),
              let milliseconds = Int(components[3]) else {
            return nil
        }
        
        return TimeInterval(hours * 3600 + minutes * 60 + seconds) + TimeInterval(milliseconds) / 1000.0
    }
} 