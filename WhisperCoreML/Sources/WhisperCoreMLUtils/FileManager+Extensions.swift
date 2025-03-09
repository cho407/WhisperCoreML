import Foundation

/// FileManager 확장
public extension FileManager {
    /// 공유 인스턴스
    static let shared = FileManager.default
    
    /// 임시 디렉토리 URL
    func temporaryDirectory() -> URL {
        return URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    }
    
    /// 문서 디렉토리 URL
    func documentsDirectory() -> URL {
        return try! url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    }
    
    /// 캐시 디렉토리 URL
    func cacheDirectory() -> URL {
        return try! url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    }
    
    /// 애플리케이션 지원 디렉토리 URL
    func applicationSupportDirectory() -> URL {
        return try! url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    }
    
    /// 디렉토리 생성
    func createDirectory(at url: URL) throws {
        try createDirectory(at: url, withIntermediateDirectories: true)
    }
    
    /// 파일 존재 여부 확인
    func fileExists(at url: URL) -> Bool {
        return fileExists(atPath: url.path)
    }
    
    /// 파일 크기 확인
    func fileSize(at url: URL) throws -> UInt64 {
        guard fileExists(at: url) else {
            throw NSError(domain: "FileManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "파일이 존재하지 않습니다."])
        }
        
        let attributes = try attributesOfItem(atPath: url.path)
        return attributes[.size] as? UInt64 ?? 0
    }
    
    /// 파일 삭제
    func deleteFile(at url: URL) throws {
        if fileExists(at: url) {
            try removeItem(at: url)
        }
    }
    
    /// 디렉토리 내 파일 목록 가져오기
    func contentsOfDirectory(at url: URL, withExtension ext: String? = nil) throws -> [URL] {
        let contents = try contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
        
        if let ext = ext {
            return contents.filter { $0.pathExtension.lowercased() == ext.lowercased() }
        } else {
            return contents
        }
    }
    
    /// 파일 복사
    func copyFile(from sourceURL: URL, to destinationURL: URL) throws {
        if fileExists(at: destinationURL) {
            try removeItem(at: destinationURL)
        }
        
        try copyItem(at: sourceURL, to: destinationURL)
    }
    
    /// 파일 이동
    func moveFile(from sourceURL: URL, to destinationURL: URL) throws {
        if fileExists(at: destinationURL) {
            try removeItem(at: destinationURL)
        }
        
        try moveItem(at: sourceURL, to: destinationURL)
    }
    
    /// 디렉토리 크기 계산
    func directorySize(at url: URL) throws -> UInt64 {
        guard fileExists(at: url) else {
            throw NSError(domain: "FileManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "디렉토리가 존재하지 않습니다."])
        }
        
        var isDirectory: ObjCBool = false
        fileExists(atPath: url.path, isDirectory: &isDirectory)
        
        guard isDirectory.boolValue else {
            throw NSError(domain: "FileManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "지정된 경로는 디렉토리가 아닙니다."])
        }
        
        let contents = try contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
        var size: UInt64 = 0
        
        for fileURL in contents {
            var isDir: ObjCBool = false
            fileExists(atPath: fileURL.path, isDirectory: &isDir)
            
            if isDir.boolValue {
                size += try directorySize(at: fileURL)
            } else {
                size += try fileSize(at: fileURL)
            }
        }
        
        return size
    }
    
    /// 디렉토리 내용 삭제 (디렉토리 자체는 유지)
    func clearDirectory(at url: URL) throws {
        guard fileExists(at: url) else { return }
        
        var isDirectory: ObjCBool = false
        fileExists(atPath: url.path, isDirectory: &isDirectory)
        
        guard isDirectory.boolValue else {
            throw NSError(domain: "FileManager", code: 4, userInfo: [NSLocalizedDescriptionKey: "지정된 경로는 디렉토리가 아닙니다."])
        }
        
        let contents = try contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
        
        for fileURL in contents {
            try removeItem(at: fileURL)
        }
    }
    
    /// 파일 확장자 변경
    func changeFileExtension(of url: URL, to newExtension: String) -> URL {
        var components = url.pathComponents
        let filename = components.last!
        let nameWithoutExtension = filename.components(separatedBy: ".").first!
        let newFilename = nameWithoutExtension + "." + newExtension
        
        components.removeLast()
        components.append(newFilename)
        
        return URL(fileURLWithPath: components.joined(separator: "/"))
    }
} 