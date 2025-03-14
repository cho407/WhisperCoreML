import SwiftUI
import WhisperCoreML

/// 설정 화면
struct SettingsView: View {
    @AppStorage("autoTranscribe") private var autoTranscribe = true
    @AppStorage("saveTranscriptions") private var saveTranscriptions = true
    @AppStorage("defaultLanguage") private var defaultLanguage = "auto"
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("트랜스크립션 설정")) {
                    Toggle("자동 트랜스크립션", isOn: $autoTranscribe)
                    Toggle("결과 자동 저장", isOn: $saveTranscriptions)
                    
                    Picker("기본 언어", selection: $defaultLanguage) {
                        Text("자동 감지").tag("auto")
                        Text("한국어").tag("ko")
                        Text("영어").tag("en")
                        Text("일본어").tag("ja")
                        Text("중국어").tag("zh")
                        Text("스페인어").tag("es")
                        Text("프랑스어").tag("fr")
                        Text("독일어").tag("de")
                        Text("이탈리아어").tag("it")
                        Text("러시아어").tag("ru")
                    }
                }
                
                Section(header: Text("휴식")) {
                    Button("임시 파일 정리") {
                        cleanTemporaryFiles()
                    }
                    
                    Button("캐시 정리") {
                        cleanCache()
                    }
                }
                
                Section(header: Text("앱 정보")) {
                    HStack {
                        Text("WhisperCoreML 버전")
                        Spacer()
                        Text(getPackageVersion())
                            .foregroundColor(.gray)
                    }
                    
                    HStack {
                        Text("앱 버전")
                        Spacer()
                        Text(getAppVersion())
                            .foregroundColor(.gray)
                    }
                    
                    Link("소스 코드", destination: URL(string: "https://github.com/cho407/WhisperCoreML")!)
                    
                    Link("Hugging Face", destination: URL(string: "https://huggingface.co/cho407/WhisperCoreML")!)
                }
                
                Section(header: Text("개발자 정보")) {
                    Link("GitHub", destination: URL(string: "https://github.com/cho407")!)
                }
            }
            .navigationTitle("설정")
        }
    }
    
    /// 임시 파일 정리
    private func cleanTemporaryFiles() {
        let fileManager = FileManager.default
        do {
            // macOS에서 임시 디렉토리 경로 얻기
            let tempDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            let tempContents = try fileManager.contentsOfDirectory(at: tempDirectoryURL, includingPropertiesForKeys: nil)
            
            // 앱 관련 임시 파일만 삭제
            let appTempFiles = tempContents.filter { url in
                url.lastPathComponent.contains("WhisperCoreML")
            }
            
            for fileURL in appTempFiles {
                try fileManager.removeItem(at: fileURL)
            }
        } catch {
            print("임시 파일 정리 실패: \(error.localizedDescription)")
        }
    }
    
    /// 캐시 정리
    private func cleanCache() {
        let fileManager = FileManager.default
        do {
            // macOS에서 캐시 디렉토리 경로 얻기
            let cacheDirectoryURL = try fileManager.url(
                for: .cachesDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: false
            ).appendingPathComponent("WhisperCoreMLSample", isDirectory: true)
            
            // 디렉토리가 있는 경우에만 처리
            if fileManager.fileExists(atPath: cacheDirectoryURL.path) {
                let cacheContents = try fileManager.contentsOfDirectory(
                    at: cacheDirectoryURL,
                    includingPropertiesForKeys: nil
                )
                
                for fileURL in cacheContents {
                    try fileManager.removeItem(at: fileURL)
                }
            }
        } catch {
            print("캐시 정리 실패: \(error.localizedDescription)")
        }
    }
    
    /// WhisperCoreML 패키지 버전 가져오기
    private func getPackageVersion() -> String {
        // 실제로는 WhisperCoreML 패키지에서 버전 정보를 가져올 수 있을 것입니다.
        // 현재는 임시 값을 반환합니다.
        return "1.0.0"
    }
    
    /// 앱 버전 가져오기
    private func getAppVersion() -> String {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        return "\(appVersion) (\(buildNumber))"
    }
}

#Preview {
    SettingsView()
} 