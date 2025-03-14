import SwiftUI

/// 메인 화면 (탭 기반)
struct MainView: View {
    @StateObject private var transcriptionViewModel = TranscriptionViewModel()
    @StateObject private var modelManagerViewModel = ModelManagerViewModel()
    
    var body: some View {
        TabView {
            TranscriptionView(viewModel: transcriptionViewModel)
                .tabItem {
                    Label("음성 인식", systemImage: "waveform")
                }
            
            ModelManagerView(viewModel: modelManagerViewModel)
                .tabItem {
                    Label("모델 관리", systemImage: "brain")
                }
            
            SettingsView()
                .tabItem {
                    Label("설정", systemImage: "gear")
                }
        }
    }
}

#Preview {
    MainView()
} 