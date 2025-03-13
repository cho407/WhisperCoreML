import Foundation
import CoreML

/// 번역 결과
public struct TranslationResult {
    /// 원본 텍스트
    public let originalText: String
    
    /// 번역된 텍스트https://huggingface.co/cho407/WhisperCoreML/tree/main
    public let translatedText: String
    
    /// 원본 언어
    public let sourceLanguage: String
    
    /// 대상 언어
    public let targetLanguage: String
    
    /// 번역 신뢰도 (0.0 ~ 1.0)
    public let confidence: Double
    
    /// 번역 시간 (초)
    public let processingTime: TimeInterval
}

/// 번역 옵션
public struct TranslationOptions {
    /// 대상 언어 (ISO 639-1 코드)
    public let targetLanguage: String
    
    /// 번역 품질 (0.0 ~ 1.0, 높을수록 더 높은 품질)
    public let quality: Float
    
    /// 보존할 형식
    public let preserveFormats: Set<PreserveFormat>
    
    /// 기본 옵션 (영어로 번역)
    public static let `default` = TranslationOptions(
        targetLanguage: "en",
        quality: 0.7,
        preserveFormats: [.numbers, .names]
    )
    
    /// 초기화
    public init(
        targetLanguage: String,
        quality: Float = 0.7,
        preserveFormats: Set<PreserveFormat> = [.numbers, .names]
    ) {
        self.targetLanguage = targetLanguage
        self.quality = quality
        self.preserveFormats = preserveFormats
    }
}

/// 번역 지원 확장
public extension WhisperModel {
    /// 오디오 파일 번역
    /// - Parameters:
    ///   - audioURL: 오디오 파일 URL
    ///   - options: 번역 옵션
    ///   - progressHandler: 진행 상황 핸들러
    /// - Returns: 번역 결과
    func translateAudio(
        _ audioURL: URL,
        options: TranslationOptions = .default,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> TranslationResult {
        // 시작 시간
        let startTime = Date()
        
        // 모델이 로드되어 있는지 확인
        if encoderModel == nil || decoderModel == nil {
            try await loadModel()
        }
        
        // 오디오 처리
        progressHandler(0.1)
        
        // 오디오 파일 로드
        let audioData = try await audioProcessor.loadAudioFile(url: audioURL)
        progressHandler(0.2)
        
        // 원본 언어 감지 (오디오에서 언어 감지)
        let detectedLanguage = try await detectLanguageFromAudio(audioData.samples)
        progressHandler(0.3)
        
        // 번역 옵션 생성
        let transcriptionOptions = TranscriptionOptions(
            language: detectedLanguage,
            task: .translateTo(options.targetLanguage),
            temperature: 0.0,
            compressionRatio: 2.4,
            logProbThreshold: -1.0,
            silenceThreshold: 0.6,
            initialPrompt: nil,
            enableWordTimestamps: false,
            translationQuality: options.quality,
            preserveFormats: options.preserveFormats
        )
        
        // 오디오 데이터에서 멜 스펙트로그램 추출
        let melSpectrogram = try audioProcessor.extractMelSpectrogram(from: audioData)
        progressHandler(0.5)
        
        // 모델 입력 준비
        let modelInput = try prepareModelInput(melSpectrogram: melSpectrogram, options: transcriptionOptions)
        progressHandler(0.6)
        
        // 인코더 모델 실행
        guard let encoder = self.encoderModel else {
            throw WhisperError.modelNotLoaded
        }
        
        // 디코더 모델 실행
        guard let decoder = self.decoderModel else {
            throw WhisperError.modelNotLoaded
        }
        
        // 인코더로 특징 추출
        let encoderOutput = try encoder.prediction(from: modelInput)
        progressHandler(0.7)
        
        // 디코더로 번역 수행
        let decoderInput = try prepareDecoderInput(from: encoderOutput, options: transcriptionOptions)
        let decoderOutput = try decoder.prediction(from: decoderInput)
        progressHandler(0.8)
        
        // 결과 처리
        let segments = try await processModelOutput(decoderOutput, options: transcriptionOptions, timeOffset: 0)
        progressHandler(0.9)
        
        // 원본 텍스트 추출 (번역 전 텍스트)
        let originalOptions = TranscriptionOptions(
            language: detectedLanguage,
            task: .transcribe
        )
        
        let originalDecoderInput = try prepareDecoderInput(from: encoderOutput, options: originalOptions)
        let originalDecoderOutput = try decoder.prediction(from: originalDecoderInput)
        let originalSegments = try await processModelOutput(originalDecoderOutput, options: originalOptions, timeOffset: 0)
        let originalText = originalSegments.map { $0.text }.joined(separator: " ")
        
        // 번역 결과 생성
        let translatedText = segments.map { $0.text }.joined(separator: " ")
        
        // 결과 반환
        progressHandler(1.0)
        return TranslationResult(
            originalText: originalText,
            translatedText: translatedText,
            sourceLanguage: detectedLanguage,
            targetLanguage: options.targetLanguage,
            confidence: 0.9,
            processingTime: Date().timeIntervalSince(startTime)
        )
    }
    
    /// 텍스트에서 언어 감지
    /// - Parameter text: 감지할 텍스트
    /// - Returns: 감지된 언어 코드
    private func detectLanguage(from text: String) async throws -> String {
        // 언어별 문자 패턴
        let patterns: [String: String] = [
            "ko": "[가-힣]",      // 한국어
            "ja": "[ぁ-んァ-ン]",  // 일본어
            "zh": "[\\u4e00-\\u9fff]", // 중국어
            "en": "[a-zA-Z]"     // 영어
        ]
        
        // 각 언어별 문자 출현 빈도 계산
        var languageScores: [String: Double] = [:]
        
        for (language, pattern) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let matches = regex.matches(
                    in: text,
                    range: NSRange(text.startIndex..., in: text)
                )
                languageScores[language] = Double(matches.count) / Double(text.count)
            }
        }
        
        // 가장 높은 빈도의 언어 반환
        return languageScores.max(by: { $0.value < $1.value })?.key ?? "en"
    }
    
    /// 오디오에서 언어 감지
    /// - Parameter audioData: 오디오 데이터
    /// - Returns: 감지된 언어 코드
    private func detectLanguageFromAudio(_ samples: [Float]) async throws -> String {
        // 처음 30초 또는 전체 오디오의 처음 부분을 사용하여 언어 감지
        let sampleCount = min(samples.count, Int(30 * 16000)) // 30초 @ 16kHz
        let audioSamples = Array(samples.prefix(sampleCount))
        
        // AudioData 객체 생성
        let audioData = AudioData(samples: audioSamples, sampleRate: 16000)
        
        // 멜 스펙트로그램 추출
        let melSpectrogram = try audioProcessor.extractMelSpectrogram(from: audioData)
        
        // 언어 감지 옵션
        let options = TranscriptionOptions(
            language: nil, // 자동 감지
            task: .transcribe
        )
        
        // 모델 입력 준비
        let modelInput = try prepareModelInput(melSpectrogram: melSpectrogram, options: options)
        
        // 인코더 모델 실행
        guard let encoder = self.encoderModel else {
            throw WhisperError.modelNotLoaded
        }
        
        // 디코더 모델 실행
        guard let decoder = self.decoderModel else {
            throw WhisperError.modelNotLoaded
        }
        
        // 인코더로 특징 추출
        let encoderOutput = try encoder.prediction(from: modelInput)
        
        // 디코더로 언어 감지
        let decoderInput = try prepareDecoderInput(from: encoderOutput, options: options)
        let decoderOutput = try decoder.prediction(from: decoderInput)
        
        // 결과 처리
        let segments = try await processModelOutput(decoderOutput, options: options, timeOffset: 0)
        
        // 향상된 언어 감지 결과 사용
        let detectionResult = enhancedLanguageDetection(from: segments)
        
        return detectionResult.language
    }
    
    /// 디코더 입력 준비
    private func prepareDecoderInput(from encoderOutput: MLFeatureProvider, options: TranscriptionOptions) throws -> MLFeatureProvider {
        // TODO: 실제 구현에서는 인코더 출력을 디코더 입력으로 변환하는 로직 구현
        // 현재는 임시로 동일한 입력을 반환
        return encoderOutput
    }
} 
