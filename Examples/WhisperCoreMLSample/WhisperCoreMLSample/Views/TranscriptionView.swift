import SwiftUI
import AVFoundation
import AppKit
import UniformTypeIdentifiers

/// 음성 인식 화면
struct TranscriptionView: View {
    @ObservedObject var viewModel: TranscriptionViewModel
    @State private var showingFilePicker = false
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
            VStack {
                // 상단 탭 바
                Picker("표시 모드", selection: $selectedTab) {
                    Text("녹음").tag(0)
                    Text("결과").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                // 탭 내용
                TabView(selection: $selectedTab) {
                    recordingView
                        .tag(0)
                    
                    resultsView
                        .tag(1)
                }
                .tabViewStyle(DefaultTabViewStyle())
            }
            .navigationTitle("WhisperCoreML 음성 인식")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        showFilePicker()
                    } label: {
                        Image(systemName: "doc.badge.plus")
                    }
                }
            }
        }
    }
    
    /// 파일 선택기 표시
    private func showFilePicker() {
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        openPanel.allowedContentTypes = [.audio, .mp3, .wav, .mpeg4Audio]
        
        openPanel.begin { response in
            if response == .OK, let url = openPanel.url {
                if let importedURL = viewModel.importAudioFile(from: url) {
                    viewModel.transcribeAudioFile(at: importedURL)
                }
            }
        }
    }
    
    /// 녹음 화면
    private var recordingView: some View {
        VStack {
            // 모델 선택
            modelSelectionView
                .padding()
            
            // 언어 선택
            languageSelectionView
                .padding(.horizontal)
            
            Spacer()
            
            // 녹음 상태 표시
            recordingStatusView
            
            Spacer()
            
            // 녹음 버튼
            recordButton
                .padding(.bottom, 40)
        }
    }
    
    /// 모델 선택 뷰
    private var modelSelectionView: some View {
        VStack(alignment: .leading) {
            Text("모델 선택")
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(viewModel.availableModels) { modelInfo in
                        modelButton(modelInfo)
                    }
                }
            }
        }
    }
    
    /// 모델 선택 버튼
    private func modelButton(_ modelInfo: ModelInfo) -> some View {
        Button {
            if modelInfo.isDownloaded || modelInfo.isBuiltIn {
                viewModel.selectedModel = modelInfo.type
            }
        } label: {
            VStack {
                Text(modelInfo.displayName)
                    .fontWeight(viewModel.selectedModel == modelInfo.type ? .bold : .regular)
                
                Text(modelInfo.formattedSize)
                    .font(.caption)
                
                Text(modelInfo.statusText)
                    .font(.caption2)
                    .foregroundColor(modelStatusColor(modelInfo))
            }
            .frame(minWidth: 80)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(viewModel.selectedModel == modelInfo.type ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(viewModel.selectedModel == modelInfo.type ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!modelInfo.isDownloaded && !modelInfo.isBuiltIn)
    }
    
    /// 모델 상태에 따른 색상 반환
    private func modelStatusColor(_ modelInfo: ModelInfo) -> Color {
        if modelInfo.isBuiltIn {
            return .green
        }
        
        if modelInfo.isDownloaded {
            return .blue
        }
        
        if modelInfo.downloadProgress != nil {
            return .orange
        }
        
        return .gray
    }
    
    /// 언어 선택 뷰
    private var languageSelectionView: some View {
        VStack(alignment: .leading) {
            Text("언어 선택")
                .font(.headline)
            
            Picker("언어", selection: $viewModel.selectedLanguage) {
                ForEach(LanguageOption.allCases) { option in
                    Text(option.displayName).tag(option)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
    }
    
    /// 녹음 상태 표시 뷰
    private var recordingStatusView: some View {
        VStack {
            if case .recording = viewModel.transcriptionState {
                // 녹음 중
                Text(timeString(from: viewModel.recordingTime))
                    .font(.system(size: 60, weight: .bold, design: .monospaced))
                    .foregroundColor(.red)
            } else if case .processing = viewModel.transcriptionState {
                // 처리 중
                VStack {
                    ProgressView(value: viewModel.transcriptionProgress)
                        .progressViewStyle(.linear)
                        .frame(width: 200)
                    
                    Text("음성 인식 중...")
                        .padding(.top, 8)
                }
            } else if case .completed(let result) = viewModel.transcriptionState {
                // 완료
                VStack {
                    Text("음성 인식 완료")
                        .font(.headline)
                    
                    Text("\(timeString(from: result.duration)) 길이의 오디오")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    Text("언어: \(result.language)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    ScrollView {
                        Text(result.text)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 200)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .padding()
                }
            } else if case .failed(let error) = viewModel.transcriptionState {
                // 실패
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                    
                    Text("오류 발생")
                        .font(.headline)
                        .padding(.top, 4)
                    
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            } else {
                // 대기 중
                VStack {
                    Image(systemName: "waveform")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    
                    Text("녹음 버튼을 눌러 시작하세요")
                        .padding(.top, 8)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
    
    /// 녹음 버튼
    private var recordButton: some View {
        Button {
            viewModel.toggleRecording()
        } label: {
            ZStack {
                Circle()
                    .fill(viewModel.isRecording ? Color.red : Color.blue)
                    .frame(width: 80, height: 80)
                
                if viewModel.isRecording {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white)
                        .frame(width: 30, height: 30)
                } else {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 70, height: 70)
                    
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 60, height: 60)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(viewModel.transcriptionState.isProcessing)
    }
    
    /// 결과 목록 화면
    private var resultsView: some View {
        Group {
            if viewModel.transcriptionResults.isEmpty {
                // macOS에 맞는 빈 상태 뷰
                VStack(spacing: 20) {
                    Image(systemName: "text.bubble")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    
                    Text("인식 결과 없음")
                        .font(.headline)
                    
                    Text("음성 인식을 수행하면 결과가 여기에 표시됩니다.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(viewModel.transcriptionResults) { result in
                        resultCell(result)
                    }
                }
            }
        }
    }
    
    /// 결과 셀
    private func resultCell(_ result: TranscriptionResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.timestamp, style: .date)
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text(result.timestamp, style: .time)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                HStack {
                    Text("모델: \(result.modelType)")
                        .font(.caption2)
                        .padding(4)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)
                    
                    Text("언어: \(result.language)")
                        .font(.caption2)
                        .padding(4)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(4)
                    
                    Text(timeString(from: result.duration))
                        .font(.caption2)
                        .padding(4)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(4)
                }
            }
            
            Text(result.text)
                .lineLimit(3)
            
            if let url = result.sourceFile, viewModel.isPlayingAudio {
                HStack {
                    Spacer()
                    Button {
                        viewModel.stopAudio()
                    } label: {
                        Label("중지", systemImage: "stop.fill")
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                }
            } else if let url = result.sourceFile {
                HStack {
                    Spacer()
                    Button {
                        viewModel.playAudio(url: url)
                    } label: {
                        Label("재생", systemImage: "play.fill")
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    /// 시간을 문자열로 변환
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        let milliseconds = Int((timeInterval.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%02d:%02d.%02d", minutes, seconds, milliseconds)
    }
}

#Preview {
    TranscriptionView(viewModel: TranscriptionViewModel())
} 
