// WhisperModel.swift
// Whisper 모델 관련 코드

import Foundation
import CoreML
import Combine

/// Whisper 모델 클래스
public class WhisperModel {
    /// 모델 타입
    public let modelType: WhisperModelType
    
    /// 모델 URL
    private let modelURL: URL
    
    /// 모델 인스턴스
    internal var model: MLModel?
    
    /// 오디오 프로세서
    public let audioProcessor = AudioProcessor()
    
    /// 취소 토큰
    internal var cancellables = Set<AnyCancellable>()
    
    /// 토크나이저
    internal private(set) var tokenizer: WhisperTokenizer
    
    /// 성능 최적화 관리자
    private let performanceOptimizer: PerformanceOptimizer
    
    /// 청크 크기 (초)
    private let chunkDuration: TimeInterval = 30.0
    
    /// 중간 결과 캐시
    private let resultCache = ResultCache()
    
    /// 초기화 메서드 (모델 타입 지정)
    /// - Parameter modelType: 모델 타입
    /// - Throws: 토크나이저 로드 실패 시 오류
    public init(modelType: WhisperModelType) throws {
        self.modelType = modelType
        self.modelURL = modelType.localModelPath()
        
        // 토크나이저 초기화
        let tokenizerResult = try Self.loadTokenizer()
        self.tokenizer = tokenizerResult
        
        // 성능 최적화 관리자 초기화
        self.performanceOptimizer = PerformanceOptimizer(configuration: .default)
    }
    
    /// 초기화 메서드 (모델 경로 직접 지정)
    /// - Parameter modelPath: 모델 파일 경로
    /// - Throws: 토크나이저 로드 실패 시 오류
    public init(modelPath: String) throws {
        // 모델 타입 추론 (파일 이름에서)
        let url = URL(fileURLWithPath: modelPath)
        let fileName = url.lastPathComponent
        
        if fileName.contains("tiny") {
            self.modelType = .tiny
        } else if fileName.contains("base") {
            self.modelType = .base
        } else if fileName.contains("small") {
            self.modelType = .small
        } else if fileName.contains("medium") {
            self.modelType = .medium
        } else if fileName.contains("large") {
            self.modelType = .large
        } else {
            // 기본값
            self.modelType = .tiny
        }
        
        self.modelURL = url
        
        // 토크나이저 초기화
        let tokenizerResult = try Self.loadTokenizer()
        self.tokenizer = tokenizerResult
        
        // 성능 최적화 관리자 초기화
        self.performanceOptimizer = PerformanceOptimizer(configuration: .default)
    }
    
    /// 모델 로드
    /// - Throws: 모델 로드 실패 시 오류
    public func loadModel() async throws {
        // 모델 매니저를 통해 모델 로드
        let modelManager = ModelManager.shared
        
        do {
            // 모델 매니저를 통해 모델 파일 확인 및 다운로드
            let modelURL = try await modelManager.loadModel(modelType)
            
            // 메모리 사용량 최적화를 위한 설정
            let config = MLModelConfiguration()
            config.computeUnits = await performanceOptimizer.recommendedComputeUnits()
            
            // 메모리 최적화 설정
            if modelType.sizeInMB >= 1000 { // 1GB 이상의 모델은 메모리 최적화 적용
                config.computeUnits = .cpuAndGPU
                config.allowLowPrecisionAccumulationOnGPU = true
                
                if #available(macOS 13.0, iOS 16.0, *) {
                    // Neural Engine 사용 가능한 경우
                    config.computeUnits = .cpuAndNeuralEngine
                }
            }
            
            // 모델 로드
            self.model = try MLModel(contentsOf: modelURL, configuration: config)
            
            print("모델 로드 성공: \(modelType.rawValue)")
        } catch {
            print("모델 로드 실패: \(error.localizedDescription)")
            throw WhisperError.modelLoadingFailed(error)
        }
    }
    
    /// 모델 다운로드
    /// - Parameter progressHandler: 진행 상황 핸들러
    /// - Returns: 다운로드 완료 Publisher
    public func downloadModel(progressHandler: @escaping (Double) -> Void) -> AnyPublisher<Void, WhisperError> {
        guard let downloadURL = modelType.downloadURL else {
            return Fail(error: WhisperError.invalidModelURL).eraseToAnyPublisher()
        }
        
        // 다운로드 디렉토리 생성
        let fileManager = FileManager.default
        let modelDirectory = modelURL.deletingLastPathComponent()
        
        do {
            if !fileManager.fileExists(atPath: modelDirectory.path) {
                try fileManager.createDirectory(at: modelDirectory, withIntermediateDirectories: true)
            }
        } catch {
            return Fail(error: WhisperError.fileSystemError(error.localizedDescription)).eraseToAnyPublisher()
        }
        
        // URLSession을 사용한 다운로드 구현
        let subject = PassthroughSubject<Void, WhisperError>()
        
        let task = URLSession.shared.downloadTask(with: downloadURL) { tempURL, response, error in
            if let error = error {
                subject.send(completion: .failure(.networkError(error.localizedDescription)))
                return
            }
            
            guard let tempURL = tempURL else {
                subject.send(completion: .failure(.downloadFailed("다운로드 파일을 찾을 수 없습니다.")))
                return
            }
            
            do {
                // 기존 파일 삭제
                if fileManager.fileExists(atPath: self.modelURL.path) {
                    try fileManager.removeItem(at: self.modelURL)
                }
                
                // 다운로드한 파일 이동
                try fileManager.moveItem(at: tempURL, to: self.modelURL)
                subject.send(())
                subject.send(completion: .finished)
            } catch {
                subject.send(completion: .failure(.fileSystemError(error.localizedDescription)))
            }
        }
        
        // 진행 상황 관찰
        task.resume()
        
        // 진행 상황 업데이트를 위한 타이머
        Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                let bytesReceived = task.countOfBytesReceived
                let bytesExpected = task.countOfBytesExpectedToReceive
                let progress = bytesExpected > 0 ? Double(bytesReceived) / Double(bytesExpected) : 0
                progressHandler(progress)
            }
            .store(in: &cancellables)
        
        return subject.eraseToAnyPublisher()
    }
    
    /// 오디오 파일에서 텍스트 추출
    public func transcribe(
        audioURL: URL,
        options: TranscriptionOptions = .default,
        progressHandler: @escaping (Double) -> Void = { _ in }
    ) async throws -> TranscriptionResult {
        // 최적화된 버전 사용
        return try await transcribeOptimized(
            audioURL: audioURL,
            options: options,
            progressHandler: progressHandler
        )
    }
    
    /// 오디오 파일에서 텍스트 추출 (최적화된 버전)
    public func transcribeOptimized(
        audioURL: URL,
        options: TranscriptionOptions = .default,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> TranscriptionResult {
        // 모델 로드 확인
        if model == nil {
            try await loadModel()
        }
        
        let startTime = Date()
        progressHandler(0.1)
        
        // 오디오 데이터 로드
        let audioData = try await audioProcessor.loadAudioFile(url: audioURL)
        
        // 청크로 분할
        let chunks = try await splitAudioIntoChunks(audioData)
        progressHandler(0.2)
        
        // 병렬 처리를 위한 TaskGroup 사용
        let segments = try await withThrowingTaskGroup(of: [TranscriptionSegment].self) { group in
            var allSegments: [TranscriptionSegment] = []
            var processedChunks = 0
            let totalChunks = chunks.count
            
            // 각 청크에 대한 작업 추가
            for chunk in chunks {
                group.addTask {
                    // 캐시된 결과 확인
                    if let cached = await self.resultCache.get(for: chunk.id) {
                        return cached
                    }
                    
                    // 멜 스펙트로그램 추출
                    let melSpectrogram = try await self.processChunk(chunk)
                    
                    // 모델 입력 준비
                    let modelInput = try self.prepareModelInput(
                        melSpectrogram: melSpectrogram,
                        options: options
                    )
                    
                    // 모델 실행 (최적화된 설정 사용)
                    guard let model = self.model else {
                        throw WhisperError.modelNotLoaded
                    }
                    
                    let prediction = try await Task.detached(priority: .userInitiated) {
                        try model.prediction(from: modelInput)
                    }.value
                    
                    // 결과 처리
                    let chunkSegments = try await self.processModelOutput(
                        prediction,
                        options: options,
                        timeOffset: chunk.startTime
                    )
                    
                    // 결과 캐시에 저장
                    await self.resultCache.cache(chunkSegments, for: chunk.id)
                    
                    return chunkSegments
                }
                
                // 청크 처리 완료 시 진행률 업데이트
                processedChunks += 1
                let progress = 0.2 + (0.7 * Double(processedChunks) / Double(totalChunks))
                progressHandler(progress)
            }
            
            // 모든 결과 수집
            for try await segments in group {
                allSegments.append(contentsOf: segments)
            }
            
            return allSegments
        }
        
        // 세그먼트 정렬 및 병합
        let mergedSegments = mergeAndSortSegments(segments)
        
        // 언어 감지 (캐시 활용)
        let detectedLanguage = await detectLanguageOptimized(from: mergedSegments, options: options)
        
        // 최종 결과 생성
        let result = TranscriptionResult(
            segments: mergedSegments,
            detectedLanguage: detectedLanguage,
            options: options,
            processingTime: Date().timeIntervalSince(startTime),
            audioDuration: audioData.duration
        )
        
        progressHandler(1.0)
        return result
    }
    
    /// 오디오 데이터를 청크로 분할
    private func splitAudioIntoChunks(_ audioData: AudioData) async throws -> [AudioChunk] {
        let totalDuration = audioData.duration
        var chunks: [AudioChunk] = []
        
        var startTime: TimeInterval = 0
        while startTime < totalDuration {
            let endTime = min(startTime + chunkDuration, totalDuration)
            let chunk = AudioChunk(
                id: UUID().uuidString,
                data: audioData.slice(from: startTime, to: endTime),
                startTime: startTime,
                endTime: endTime
            )
            chunks.append(chunk)
            startTime = endTime
        }
        
        return chunks
    }
    
    /// 청크 처리
    private func processChunk(_ chunk: AudioChunk) async throws -> [Float] {
        // 멜 스펙트로그램 추출 최적화
        if let cached = await resultCache.getMelSpectrogram(for: chunk.id) {
            return cached
        }
        
        let melSpectrogram = try audioProcessor.extractMelSpectrogram(from: chunk.data)
        await resultCache.cacheMelSpectrogram(melSpectrogram, for: chunk.id)
        return melSpectrogram
    }
    
    /// 세그먼트 병합 및 정렬
    private func mergeAndSortSegments(_ segments: [TranscriptionSegment]) -> [TranscriptionSegment] {
        // 시간순 정렬
        let sortedSegments = segments.sorted { $0.start < $1.start }
        
        // 인접한 세그먼트 병합
        var mergedSegments: [TranscriptionSegment] = []
        var currentSegment: TranscriptionSegment?
        
        for segment in sortedSegments {
            if let current = currentSegment {
                // 시간 간격이 작고 같은 화자인 경우 병합
                if segment.start - current.end < 0.3 {
                    currentSegment = TranscriptionSegment(
                        id: current.id,
                        index: current.index,
                        text: current.text + " " + segment.text,
                        start: current.start,
                        end: segment.end
                    )
                    continue
                }
            }
            
            if let current = currentSegment {
                mergedSegments.append(current)
            }
            currentSegment = segment
        }
        
        if let last = currentSegment {
            mergedSegments.append(last)
        }
        
        // 인덱스 재할당 (최적화된 방식)
        var result: [TranscriptionSegment] = []
        for (index, segment) in mergedSegments.enumerated() {
            // 인덱스가 이미 올바른 경우 불필요한 객체 생성 방지
            if segment.index == index {
                result.append(segment)
            } else {
                result.append(TranscriptionSegment(
                    id: segment.id,
                    index: index,
                    text: segment.text,
                    start: segment.start,
                    end: segment.end,
                    confidence: segment.confidence,
                    words: segment.words
                ))
            }
        }
        return result
    }
    
    /// 모델 입력 준비
    /// - Parameters:
    ///   - melSpectrogram: 멜 스펙트로그램
    ///   - options: 변환 옵션
    /// - Returns: 모델 입력
    internal func prepareModelInput(melSpectrogram: [Float], options: TranscriptionOptions) throws -> MLFeatureProvider {
        // 실제 구현에서는 CoreML 모델의 입력 요구사항에 맞게 구현
        // 이 예제에서는 간소화된 버전 제공
        
        let inputName = "mel_spectrogram"
        let shape = [1, 80, melSpectrogram.count / 80] as [NSNumber]
        
        guard let multiArray = try? MLMultiArray(shape: shape, dataType: .float32) else {
            throw WhisperError.modelInputPreparationFailed("멀티어레이 생성 실패")
        }
        
        // 멜 스펙트로그램 데이터 복사
        for i in 0..<melSpectrogram.count {
            multiArray[i] = NSNumber(value: melSpectrogram[i])
        }
        
        // 입력 딕셔너리 생성
        let inputFeatures = [inputName: multiArray]
        
        return try MLDictionaryFeatureProvider(dictionary: inputFeatures)
    }
    
    /// 모델 출력 처리
    /// - Parameters:
    ///   - modelOutput: 모델 출력
    ///   - options: 변환 옵션
    ///   - timeOffset: 시간 오프셋 (청크 처리 시 사용)
    /// - Returns: 변환 세그먼트 배열
    internal func processModelOutput(
        _ modelOutput: MLFeatureProvider,
        options: TranscriptionOptions,
        timeOffset: TimeInterval
    ) async throws -> [TranscriptionSegment] {
        // CoreML 모델의 출력 형식에 맞게 구현
        
        // 토큰 배열 가져오기
        guard let tokenArray = modelOutput.featureValue(for: "tokens")?.multiArrayValue else {
            throw WhisperError.modelOutputProcessingFailed("토큰 배열을 찾을 수 없음")
        }
        
        // 토큰 ID 배열로 변환
        let tokenIds = (0..<tokenArray.count).map { Int(truncating: tokenArray[$0]) }
        
        // 세그먼트 정보 가져오기 (시작 시간, 종료 시간)
        var segments: [TranscriptionSegment] = []
        var currentSegment: (text: String, startTime: Double, endTime: Double)? = nil
        var currentTokens: [Int] = []
        var segmentIndex = 0
        
        // 특수 토큰 ID
        let startOfTranscriptToken = tokenizer.specialTokens["<|startoftranscript|>"] ?? -1
        let endOfTranscriptToken = tokenizer.specialTokens["<|endoftranscript|>"] ?? -1
        let startOfSegmentToken = tokenizer.specialTokens["<|startofprev|>"] ?? -1
        let timestampTokenStart = tokenizer.specialTokens["<|0.00|>"] ?? -1
        
        // 언어별 처리 최적화
        let language = options.language ?? "en"
        
        // 토큰 처리
        for tokenId in tokenIds {
            // 시작 토큰 무시
            if tokenId == startOfTranscriptToken || tokenId == startOfSegmentToken {
                continue
            }
            
            // 종료 토큰이면 현재 세그먼트 완료
            if tokenId == endOfTranscriptToken {
                if let segment = currentSegment {
                    let text = tokenizer.decode(currentTokens)
                    segments.append(TranscriptionSegment(
                        id: UUID(),
                        index: segmentIndex,
                        text: processText(text, language: language),
                        start: segment.startTime + timeOffset,
                        end: segment.endTime + timeOffset
                    ))
                    segmentIndex += 1
                }
                break
            }
            
            // 타임스탬프 토큰 처리
            if tokenId >= timestampTokenStart && tokenId < timestampTokenStart + 1500 {
                // 타임스탬프 값 계산 (초 단위)
                let timestampValue = Double(tokenId - timestampTokenStart) * 0.02
                
                // 이전 세그먼트가 있으면 완료
                if let segment = currentSegment {
                    let text = tokenizer.decode(currentTokens)
                    segments.append(TranscriptionSegment(
                        id: UUID(),
                        index: segmentIndex,
                        text: processText(text, language: language),
                        start: segment.startTime + timeOffset,
                        end: timestampValue + timeOffset
                    ))
                    segmentIndex += 1
                    currentTokens = []
                }
                
                // 새 세그먼트 시작
                currentSegment = (text: "", startTime: timestampValue, endTime: 0.0)
                continue
            }
            
            // 일반 토큰 처리
            currentTokens.append(tokenId)
        }
        
        // 마지막 세그먼트 처리
        if let segment = currentSegment, !currentTokens.isEmpty {
            let text = tokenizer.decode(currentTokens)
            segments.append(TranscriptionSegment(
                id: UUID(),
                index: segmentIndex,
                text: processText(text, language: language),
                start: segment.startTime + timeOffset,
                end: segment.startTime + timeOffset + 5.0
            ))
            segmentIndex += 1
        }
        
        // 세그먼트가 없으면 더미 세그먼트 생성
        if segments.isEmpty {
            segments.append(TranscriptionSegment(
                id: UUID(),
                index: 0,
                text: "텍스트를 추출할 수 없습니다.",
                start: timeOffset,
                end: timeOffset + 5.0
            ))
        }
        
        return segments
    }
    
    /// 텍스트 후처리
    /// - Parameters:
    ///   - text: 원본 텍스트
    ///   - language: 언어 코드
    /// - Returns: 처리된 텍스트
    private func processText(_ text: String, language: String) -> String {
        var processedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 언어별 최적화된 처리 규칙
        if let rules = TextProcessingRules.shared.getRules(for: language) {
            processedText = rules.apply(to: processedText)
        }
        
        return processedText
    }
    
    /// 토크나이저 로드
    private static func loadTokenizer() throws -> WhisperTokenizer {
        // 기본 토큰 및 특수 토큰 정의
        let defaultTokens = ["<|startoftranscript|>", "<|endoftranscript|>", "<|startofprev|>", "<|0.00|>"]
        let specialTokens = [
            "<|startoftranscript|>": 1,
            "<|endoftranscript|>": 2,
            "<|startofprev|>": 3,
            "<|0.00|>": 4
        ]
        
        return WhisperTokenizer(tokens: defaultTokens, specialTokens: specialTokens)
    }
    
    /// 언어 감지
    /// - Parameter segments: 변환 세그먼트 배열
    /// - Returns: 감지된 언어 코드
    private func detectLanguage(from segments: [TranscriptionSegment]) -> String? {
        guard !segments.isEmpty else { return nil }
        
        // 전체 텍스트 결합
        let fullText = segments.map { $0.text }.joined(separator: " ")
        
        // 언어별 문자 패턴 (확장된 언어 지원)
        let patterns: [String: String] = [
            "ko": "[가-힣]",      // 한국어
            "ja": "[ぁ-んァ-ン]",  // 일본어
            "zh": "[\\u4e00-\\u9fff]", // 중국어
            "en": "[a-zA-Z]",     // 영어
            "ru": "[А-Яа-я]",     // 러시아어
            "ar": "[\\u0600-\\u06FF]", // 아랍어
            "hi": "[\\u0900-\\u097F]", // 힌디어
            "de": "[a-zA-ZäöüÄÖÜß]", // 독일어
            "fr": "[a-zA-ZàâäæçéèêëîïôœùûüÿÀÂÄÆÇÉÈÊËÎÏÔŒÙÛÜŸ]", // 프랑스어
            "es": "[a-zA-ZáéíóúüñÁÉÍÓÚÜÑ]", // 스페인어
            "it": "[a-zA-ZàèéìíîòóùúÀÈÉÌÍÎÒÓÙÚ]", // 이탈리아어
            "pt": "[a-zA-ZáàâãéèêíìóòôõúùÁÀÂÃÉÈÊÍÌÓÒÔÕÚÙ]", // 포르투갈어
            "nl": "[a-zA-ZäëïöüÄËÏÖÜ]", // 네덜란드어
            "tr": "[a-zA-ZçğıöşüÇĞİÖŞÜ]", // 터키어
            "pl": "[a-zA-ZąćęłńóśźżĄĆĘŁŃÓŚŹŻ]", // 폴란드어
            "uk": "[А-Яа-яЇїІіЄєҐґ]", // 우크라이나어
            "vi": "[a-zA-ZàáâãèéêìíòóôõùúýăđĩũơưẠạẢảẤấẦầẨẩẪẫẬậẮắẰằẲẳẴẵẶặẸẹẺẻẼẽẾếỀềỂểỄễỆệỈỉỊịỌọỎỏỐốỒồỔổỖỗỘộỚớỜờỞởỠỡỢợỤụỦủỨứỪừỬửỮữỰựỲỳỴỵỶỷỸỹ]" // 베트남어
        ]
        
        // 각 언어별 문자 출현 빈도 계산
        var languageScores: [String: Double] = [:]
        
        for (language, pattern) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let matches = regex.matches(
                    in: fullText,
                    range: NSRange(fullText.startIndex..., in: fullText)
                )
                
                // 텍스트 길이에 대한 상대적 빈도 계산
                let frequency = Double(matches.count) / Double(fullText.count)
                
                // 최소 임계값 적용 (노이즈 제거)
                if frequency > 0.05 {
                    languageScores[language] = frequency
                }
            }
        }
        
        // 언어 점수 가중치 적용 (특정 언어 패턴이 더 구체적인 경우 가중치 부여)
        let weightedScores = languageScores.mapValues { score in
            var weightedScore = score
            
            // 아시아 언어는 라틴 문자보다 더 구체적인 패턴을 가지므로 가중치 부여
            if ["ko", "ja", "zh", "ar", "hi"].contains(where: { $0 == languageScores.keys.first }) {
                weightedScore *= 1.2
            }
            
            return weightedScore
        }
        
        // 가장 높은 빈도의 언어 반환
        return weightedScores.max(by: { $0.value < $1.value })?.key
    }
    
    /// 향상된 언어 감지 결과
    private struct EnhancedLanguageDetection {
        let language: String
        let confidence: Double
    }
    
    /// 향상된 언어 감지
    /// - Parameter segments: 변환 세그먼트 배열
    /// - Returns: 언어 감지 결과
    private func enhancedLanguageDetection(from segments: [TranscriptionSegment]) -> EnhancedLanguageDetection {
        // 기본 언어 감지
        let detectedLanguage = detectLanguage(from: segments) ?? "en"
        
        // 신뢰도 계산 (실제 구현에서는 더 복잡한 로직 사용)
        let confidence = 0.9
        
        return EnhancedLanguageDetection(language: detectedLanguage, confidence: confidence)
    }
    
    /// 모델 정보 가져오기
    /// - Returns: 모델 정보 딕셔너리
    public func getModelInfo() -> [String: Any] {
        var info: [String: Any] = [
            "model_type": modelType.rawValue,
            "model_name": modelType.displayName,
            "model_size_mb": modelType.sizeInMB
        ]
        
        if let fileSize = modelType.modelFileSize() {
            info["file_size_bytes"] = fileSize
        }
        
        info["model_exists"] = modelType.modelExists()
        info["model_path"] = modelURL.path
        
        return info
    }
    
    /// 모델 삭제
    /// - Returns: 성공 여부
    public func deleteModel() throws {
        // 모델 인스턴스 해제
        model = nil
        
        // 파일 삭제
        if FileManager.default.fileExists(atPath: modelURL.path) {
            try FileManager.default.removeItem(at: modelURL)
        }
    }
    
    /// 성능 최적화 제안 가져오기
    public func getOptimizationSuggestions() async -> [String] {
        return await performanceOptimizer.getOptimizationSuggestions()
    }
    
    /// 최적화된 언어 감지
    private func detectLanguageOptimized(from segments: [TranscriptionSegment], options: TranscriptionOptions) async -> String {
        // 사용자가 지정한 언어가 있으면 그대로 사용
        if let specifiedLanguage = options.language {
            return specifiedLanguage
        }
        
        // 캐시된 언어 감지 결과 확인
        if let cachedResult = await LanguageDetectionCache.shared.getCachedResult(for: segments) {
            return cachedResult
        }
        
        // 새로운 언어 감지 수행
        let detectedLanguage = detectLanguage(from: segments) ?? "en"
        
        // 결과 캐시에 저장
        await LanguageDetectionCache.shared.cacheResult(detectedLanguage, for: segments)
        
        return detectedLanguage
    }
}

/// Whisper 모델 관리자
public class WhisperModelManager {
    /// 싱글톤 인스턴스
    public static let shared = WhisperModelManager()
    
    /// 모델 저장 디렉토리
    private let modelsDirectory: URL
    
    /// 초기화
    private init() {
        // 앱 지원 디렉토리에 모델 저장
        let fileManager = FileManager.default
        let appSupportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.modelsDirectory = appSupportDirectory.appendingPathComponent("WhisperModels", isDirectory: true)
        
        // 디렉토리 생성
        try? fileManager.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
    }
    
    /// 사용 가능한 모델 목록 반환
    public func getAvailableModels() async throws -> [WhisperModelType] {
        let fileManager = FileManager.default
        var availableModels: [WhisperModelType] = []
        
        // 모든 모델 타입에 대해 확인
        for modelType in WhisperModelType.allCases {
            let modelURL = modelsDirectory.appendingPathComponent("\(modelType.rawValue).mlmodelc")
            if fileManager.fileExists(atPath: modelURL.path) {
                availableModels.append(modelType)
            }
        }
        
        return availableModels
    }
    
    /// 모델 로드
    public func loadModel(_ modelType: WhisperModelType) async throws -> WhisperModel {
        let model = try WhisperModel(modelType: modelType)
        try await model.loadModel()
        return model
    }
    
    /// 모델 다운로드
    public func downloadModel(_ modelType: WhisperModelType) async throws {
        guard let downloadURL = modelType.downloadURL else {
            throw WhisperError.downloadFailed("다운로드 URL이 없습니다.")
        }
        
        let destinationURL = modelsDirectory.appendingPathComponent("\(modelType.rawValue).mlmodelc")
        let fileManager = FileManager.default
        
        // 이미 존재하는 경우 삭제
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        
        // 다운로드 및 저장
        let (tempURL, _) = try await URLSession.shared.download(from: downloadURL)
        try fileManager.moveItem(at: tempURL, to: destinationURL)
    }
}

/// 텍스트 처리 규칙 관리
private struct TextProcessingRules {
    static let shared = TextProcessingRules()
    
    private let rules: [String: TextProcessingRule]
    
    private init() {
        // 언어별 처리 규칙 초기화
        var rules: [String: TextProcessingRule] = [:]
        
        // 한국어 규칙
        rules["ko"] = TextProcessingRule(patterns: [
            (" 니다", "니다"),
            (" 요", "요"),
            ("  ", " ")
        ])
        
        // 일본어 규칙
        rules["ja"] = TextProcessingRule(patterns: [
            (" 。", "。"),
            (" 、", "、"),
            ("  ", " ")
        ])
        
        // 중국어 규칙
        rules["zh"] = TextProcessingRule(patterns: [
            (" 。", "。"),
            (" ，", "，"),
            ("  ", " ")
        ])
        
        self.rules = rules
    }
    
    func getRules(for language: String) -> TextProcessingRule? {
        return rules[language]
    }
}

/// 텍스트 처리 규칙
private struct TextProcessingRule {
    let patterns: [(String, String)]
    
    func apply(to text: String) -> String {
        var result = text
        for (pattern, replacement) in patterns {
            result = result.replacingOccurrences(of: pattern, with: replacement)
        }
        return result
    }
}

/// 언어 감지 캐시
private actor LanguageDetectionCache {
    static let shared = LanguageDetectionCache()
    
    private var cache: [String: String] = [:]
    private let maxCacheSize = 100
    
    func getCachedResult(for segments: [TranscriptionSegment]) -> String? {
        let key = getCacheKey(for: segments)
        return cache[key]
    }
    
    func cacheResult(_ language: String, for segments: [TranscriptionSegment]) {
        let key = getCacheKey(for: segments)
        
        // 캐시 크기 관리
        if cache.count >= maxCacheSize {
            cache.removeAll()
        }
        
        cache[key] = language
    }
    
    private func getCacheKey(for segments: [TranscriptionSegment]) -> String {
        // 첫 번째 세그먼트의 텍스트로 키 생성
        return segments.prefix(2).map { $0.text }.joined()
    }
}

/// 오디오 청크 구조체
private struct AudioChunk {
    let id: String
    let data: AudioData
    let startTime: TimeInterval
    let endTime: TimeInterval
}

/// 결과 캐시
private actor ResultCache {
    private var segmentCache: [String: [TranscriptionSegment]] = [:]
    private var melSpectrogramCache: [String: [Float]] = [:]
    private let maxCacheSize = 50
    
    func get(for id: String) -> [TranscriptionSegment]? {
        return segmentCache[id]
    }
    
    func cache(_ segments: [TranscriptionSegment], for id: String) {
        manageCacheSize()
        segmentCache[id] = segments
    }
    
    func getMelSpectrogram(for id: String) -> [Float]? {
        return melSpectrogramCache[id]
    }
    
    func cacheMelSpectrogram(_ melSpectrogram: [Float], for id: String) {
        manageCacheSize()
        melSpectrogramCache[id] = melSpectrogram
    }
    
    private func manageCacheSize() {
        if segmentCache.count > maxCacheSize {
            segmentCache.removeAll()
        }
        if melSpectrogramCache.count > maxCacheSize {
            melSpectrogramCache.removeAll()
        }
    }
}
