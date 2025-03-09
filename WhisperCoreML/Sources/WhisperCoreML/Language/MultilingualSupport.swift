import Foundation

/// 언어 감지 결과
public struct LanguageDetectionResult {
    public let language: String
    public let confidence: Double
    public let alternativeLanguages: [(language: String, confidence: Double)]
}

/// 발음 규칙
public struct PronunciationRule {
    let pattern: String
    let replacement: String
    let context: PronunciationContext
    
    public init(pattern: String, replacement: String, context: PronunciationContext = .any) {
        self.pattern = pattern
        self.replacement = replacement
        self.context = context
    }
}

/// 발음 규칙 적용 컨텍스트
public enum PronunciationContext {
    case start          // 단어 시작
    case end           // 단어 끝
    case any           // 모든 위치
    case between(String, String)  // 특정 문자 사이
}

/// 다국어 지원 확장
public extension WhisperModel {
    /// 언어별 최적화된 설정
    struct LanguageOptimization {
        public let language: String
        public let tokenizerAdjustments: [String: String]
        public let pronunciationRules: [PronunciationRule]
        public let specialCharacters: Set<Character>
        
        public init(
            language: String,
            tokenizerAdjustments: [String: String] = [:],
            pronunciationRules: [PronunciationRule] = [],
            specialCharacters: Set<Character> = []
        ) {
            self.language = language
            self.tokenizerAdjustments = tokenizerAdjustments
            self.pronunciationRules = pronunciationRules
            self.specialCharacters = specialCharacters
        }
    }
    
    /// 기본 언어 최적화 설정
    static let defaultOptimizations: [String: LanguageOptimization] = [
        "ko": LanguageOptimization(
            language: "ko",
            pronunciationRules: [
                PronunciationRule(pattern: "ㄱㅅ", replacement: "ㄳ"),
                PronunciationRule(pattern: "ㄴㅈ", replacement: "ㄵ"),
                PronunciationRule(pattern: "ㄹㄱ", replacement: "ㄺ"),
                PronunciationRule(pattern: "ㄹㅁ", replacement: "ㄻ"),
                PronunciationRule(pattern: "ㄹㅂ", replacement: "ㄼ"),
                PronunciationRule(pattern: "ㄹㅅ", replacement: "ㄽ"),
                PronunciationRule(pattern: "ㄹㅌ", replacement: "ㄾ"),
                PronunciationRule(pattern: "ㄹㅍ", replacement: "ㄿ"),
                PronunciationRule(pattern: "ㄹㅎ", replacement: "ㅀ"),
                PronunciationRule(pattern: "ㅂㅅ", replacement: "ㅄ")
            ],
            specialCharacters: Set(".,!?~")
        ),
        "ja": LanguageOptimization(
            language: "ja",
            pronunciationRules: [
                PronunciationRule(pattern: "っ([かきくけこ])", replacement: "k$1"),
                PronunciationRule(pattern: "っ([さしすせそ])", replacement: "s$1"),
                PronunciationRule(pattern: "っ([たちつてと])", replacement: "t$1"),
                PronunciationRule(pattern: "っ([ぱぴぷぺぽ])", replacement: "p$1")
            ],
            specialCharacters: Set("。、！？～")
        ),
        "zh": LanguageOptimization(
            language: "zh",
            pronunciationRules: [
                PronunciationRule(pattern: "er", replacement: "儿", context: .end),
                PronunciationRule(pattern: "ng", replacement: "ng", context: .end)
            ],
            specialCharacters: Set("。，！？～")
        )
    ]
    
    /// 언어 감지 향상
    /// - Parameter segments: 전사 세그먼트 배열
    /// - Returns: 향상된 언어 감지 결과
    func enhancedLanguageDetection(from segments: [TranscriptionSegment]) -> LanguageDetectionResult {
        var languageScores: [String: Double] = [:]
        let totalCharacters = segments.reduce(0) { $0 + $1.text.count }
        
        // 언어별 특성 분석
        for segment in segments {
            let text = segment.text
            
            // 한글 특성
            let koreanCharacters = text.filter { $0.isKorean }
            if !koreanCharacters.isEmpty {
                languageScores["ko", default: 0] += Double(koreanCharacters.count) / Double(totalCharacters)
            }
            
            // 일본어 특성
            let japaneseCharacters = text.filter { $0.isJapanese }
            if !japaneseCharacters.isEmpty {
                languageScores["ja", default: 0] += Double(japaneseCharacters.count) / Double(totalCharacters)
            }
            
            // 중국어 특성
            let chineseCharacters = text.filter { $0.isChinese }
            if !chineseCharacters.isEmpty {
                languageScores["zh", default: 0] += Double(chineseCharacters.count) / Double(totalCharacters)
            }
            
            // 영어 특성
            let englishCharacters = text.filter { $0.isEnglish }
            if !englishCharacters.isEmpty {
                languageScores["en", default: 0] += Double(englishCharacters.count) / Double(totalCharacters)
            }
        }
        
        // 결과 정렬
        let sortedScores = languageScores.sorted { $0.value > $1.value }
        
        guard let primaryLanguage = sortedScores.first else {
            return LanguageDetectionResult(
                language: "en",
                confidence: 1.0,
                alternativeLanguages: []
            )
        }
        
        let alternatives = Array(sortedScores.dropFirst().prefix(2))
            .map { ($0.key, $0.value) }
        
        return LanguageDetectionResult(
            language: primaryLanguage.key,
            confidence: primaryLanguage.value,
            alternativeLanguages: alternatives
        )
    }
    
    /// 언어별 최적화 설정 적용
    /// - Parameter optimization: 언어 최적화 설정
    func applyLanguageOptimization(_ optimization: LanguageOptimization) {
        // 토크나이저 조정
        for (original, adjusted) in optimization.tokenizerAdjustments {
            tokenizer.addSpecialToken(original, adjusted)
        }
        
        // 발음 규칙 적용
        for rule in optimization.pronunciationRules {
            applyPronunciationRule(rule)
        }
        
        // 특수 문자 처리
        handleSpecialCharacters(optimization.specialCharacters)
    }
    
    /// 발음 규칙 적용
    private func applyPronunciationRule(_ rule: PronunciationRule) {
        switch rule.context {
        case .start:
            let pattern = "^" + rule.pattern
            tokenizer.addPronunciationRule(pattern: pattern, replacement: rule.replacement)
        case .end:
            let pattern = rule.pattern + "$"
            tokenizer.addPronunciationRule(pattern: pattern, replacement: rule.replacement)
        case .any:
            tokenizer.addPronunciationRule(pattern: rule.pattern, replacement: rule.replacement)
        case .between(let before, let after):
            let pattern = before + rule.pattern + after
            tokenizer.addPronunciationRule(pattern: pattern, replacement: before + rule.replacement + after)
        }
    }
    
    /// 특수 문자 처리
    private func handleSpecialCharacters(_ characters: Set<Character>) {
        for char in characters {
            // 특수 문자를 토큰으로 등록
            tokenizer.addSpecialToken(String(char), String(char))
            
            // 특수 문자 전후 처리 규칙 추가
            let beforeSpace = PronunciationRule(
                pattern: "\\s" + String(char),
                replacement: String(char),
                context: .any
            )
            let afterSpace = PronunciationRule(
                pattern: String(char) + "\\s",
                replacement: String(char),
                context: .any
            )
            
            applyPronunciationRule(beforeSpace)
            applyPronunciationRule(afterSpace)
        }
    }
}

// MARK: - Character Extensions
private extension Character {
    var isKorean: Bool {
        let scalars = unicodeScalars
        return scalars.contains { scalar in
            (0xAC00...0xD7AF).contains(scalar.value)
        }
    }
    
    var isJapanese: Bool {
        let scalars = unicodeScalars
        return scalars.contains { scalar in
            (0x3040...0x309F).contains(scalar.value) ||  // Hiragana
            (0x30A0...0x30FF).contains(scalar.value) ||  // Katakana
            (0x4E00...0x9FFF).contains(scalar.value)     // Kanji
        }
    }
    
    var isChinese: Bool {
        let scalars = unicodeScalars
        return scalars.contains { scalar in
            (0x4E00...0x9FFF).contains(scalar.value)
        }
    }
    
    var isEnglish: Bool {
        let scalars = unicodeScalars
        return scalars.contains { scalar in
            (0x0041...0x005A).contains(scalar.value) ||  // A-Z
            (0x0061...0x007A).contains(scalar.value)     // a-z
        }
    }
} 