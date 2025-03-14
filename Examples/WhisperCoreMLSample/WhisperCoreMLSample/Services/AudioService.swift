import Foundation
import AVFoundation
import Combine

/// 오디오 녹음 및 파일 처리를 위한 서비스 클래스
class AudioService: NSObject, ObservableObject {
    // MARK: - 속성
    
    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    
    @Published var isRecording = false
    @Published var isPlaying = false
    @Published var recordingTime: TimeInterval = 0
    @Published var recordedFiles: [AudioFileInfo] = []
    
    private var recordingTimer: Timer?
    private var startTime: Date?
    
    // MARK: - 초기화
    
    override init() {
        super.init()
        // macOS에서는 AVAudioSession 설정이 필요 없음
        loadRecordedFiles()
    }
    
    // MARK: - 녹음 시작
    
    func startRecording() {
        let audioFilename = getDocumentsDirectory().appendingPathComponent("\(Date().timeIntervalSince1970).m4a")
        
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            // macOS에서는 마이크 접근 권한을 시스템 설정에서 확인해야 함
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record()
            
            isRecording = true
            startTime = Date()
            
            // 녹음 시간 업데이트를 위한 타이머 시작
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self = self, let startTime = self.startTime else { return }
                self.recordingTime = Date().timeIntervalSince(startTime)
            }
        } catch {
            print("녹음 시작 실패: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 녹음 중지
    
    func stopRecording() -> URL? {
        audioRecorder?.stop()
        recordingTimer?.invalidate()
        recordingTimer = nil
        isRecording = false
        
        // 녹음된 파일 목록 갱신
        loadRecordedFiles()
        
        return audioRecorder?.url
    }
    
    // MARK: - 오디오 재생
    
    func playAudio(url: URL) {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.play()
            isPlaying = true
        } catch {
            print("오디오 재생 실패: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 오디오 중지
    
    func stopPlaying() {
        audioPlayer?.stop()
        isPlaying = false
    }
    
    // MARK: - 파일 관리
    
    func loadRecordedFiles() {
        let fileManager = FileManager.default
        let documentsURL = getDocumentsDirectory()
        
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey])
            
            // 오디오 파일만 필터링
            let audioFileURLs = fileURLs.filter { $0.pathExtension == "m4a" }
            
            // 파일 정보 로드
            recordedFiles = audioFileURLs.compactMap { url in
                do {
                    let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey, .creationDateKey])
                    let fileSize = resourceValues.fileSize ?? 0
                    let creationDate = resourceValues.creationDate ?? Date()
                    
                    // 오디오 파일 길이 가져오기
                    let player = try AVAudioPlayer(contentsOf: url)
                    let duration = player.duration
                    
                    return AudioFileInfo(url: url, duration: duration, fileSize: Int64(fileSize), createdAt: creationDate)
                } catch {
                    print("파일 정보 로드 실패: \(error.localizedDescription)")
                    return nil
                }
            }.sorted(by: { $0.createdAt > $1.createdAt }) // 최신 파일 순으로 정렬
        } catch {
            print("녹음된 파일 목록 로드 실패: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 파일 삭제
    
    func deleteRecording(at url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
            // 목록 갱신
            loadRecordedFiles()
        } catch {
            print("파일 삭제 실패: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 임포트한 파일 복사
    
    func importAudioFile(from url: URL) -> URL? {
        let fileManager = FileManager.default
        let destURL = getDocumentsDirectory().appendingPathComponent("\(Date().timeIntervalSince1970)_\(url.lastPathComponent)")
        
        do {
            try fileManager.copyItem(at: url, to: destURL)
            loadRecordedFiles()
            return destURL
        } catch {
            print("파일 임포트 실패: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - 유틸리티
    
    private func getDocumentsDirectory() -> URL {
        // macOS에서는 Application Support 디렉토리 사용
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupportDirectory = paths[0].appendingPathComponent("WhisperCoreMLSample", isDirectory: true)
        
        // 디렉토리가 없으면 생성
        if !FileManager.default.fileExists(atPath: appSupportDirectory.path) {
            try? FileManager.default.createDirectory(at: appSupportDirectory, withIntermediateDirectories: true, attributes: nil)
        }
        
        return appSupportDirectory
    }
}

// MARK: - AVAudioRecorderDelegate
extension AudioService: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            print("녹음 실패")
        }
    }
}

// MARK: - AVAudioPlayerDelegate
extension AudioService: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
    }
} 