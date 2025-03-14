import SwiftUI
import WhisperCoreML

/// 모델 관리 화면
struct ModelManagerView: View {
    @ObservedObject var viewModel: ModelManagerViewModel
    @State private var showingDeleteAlert = false
    @State private var modelToDelete: WhisperModelType?
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("사용 가능한 모델")) {
                    ForEach(viewModel.modelInfos) { modelInfo in
                        modelRow(modelInfo)
                    }
                }
                
                Section(header: Text("저장 공간")) {
                    storageUsageView
                }
            }
            .navigationTitle("모델 관리")
            .refreshable {
                viewModel.loadModels()
            }
            .alert("모델 삭제", isPresented: $showingDeleteAlert) {
                Button("취소", role: .cancel) {}
                Button("삭제", role: .destructive) {
                    if let modelType = modelToDelete {
                        viewModel.deleteModel(modelType)
                    }
                }
            } message: {
                if let modelType = modelToDelete {
                    Text("\(modelType.displayName) 모델을 삭제하시겠습니까?")
                }
            }
        }
    }
    
    /// 모델 행 뷰
    private func modelRow(_ modelInfo: ModelInfo) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(modelInfo.displayName)
                    .font(.headline)
                
                Text("\(modelInfo.formattedSize)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            if let progress = modelInfo.downloadProgress {
                // 다운로드 중
                VStack {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .frame(width: 100)
                    
                    Text("\(Int(progress * 100))%")
                        .font(.caption)
                }
                
                Button {
                    viewModel.cancelDownload()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                }
            } else if modelInfo.isDownloaded || modelInfo.isBuiltIn {
                // 다운로드됨
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    
                    if !modelInfo.isBuiltIn {
                        Button {
                            modelToDelete = modelInfo.type
                            showingDeleteAlert = true
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                    }
                }
            } else {
                // 다운로드 필요
                Button {
                    viewModel.downloadModel(modelInfo.type)
                } label: {
                    Text("다운로드")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    /// 저장 공간 사용량 뷰
    private var storageUsageView: some View {
        let usage = viewModel.calculateStorageUsage()
        let totalSize = ByteCountFormatter.string(fromByteCount: usage.total, countStyle: .file)
        
        return VStack(alignment: .leading, spacing: 12) {
            Text("전체 사용량: \(totalSize)")
                .font(.headline)
            
            ForEach(usage.breakdown.sorted(by: { $0.key < $1.key }), id: \.key) { modelName, size in
                HStack {
                    Text(modelName)
                    Spacer()
                    Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                        .foregroundColor(.gray)
                }
                .font(.subheadline)
            }
        }
    }
}

#Preview {
    ModelManagerView(viewModel: ModelManagerViewModel())
} 