// WhisperTokenizer.swift
// Whisper 토크나이저 관련 코드

import Foundation

/// Whisper 토크나이저
public final class WhisperTokenizer: Codable {
    public private(set) var tokens: [String]
    public private(set) var specialTokens: [String: Int]
    
    /// 토큰 ID -> 토큰 매핑
    private var idToToken: [Int: String] = [:]
    
    /// 토큰 -> 토큰 ID 매핑
    private var tokenToId: [String: Int] = [:]
    
    /// 발음 규칙
    private var pronunciationRules: [(pattern: String, replacement: String)] = []
    
    /// 언어 토큰 매핑
    public private(set) var languageTokens: [String: Int] = [:]
    
    /// 초기화 메서드
    public init(tokens: [String], specialTokens: [String: Int]) {
        self.tokens = tokens
        self.specialTokens = specialTokens
        self.tokenToId = Dictionary(uniqueKeysWithValues: tokens.enumerated().map { ($0.element, $0.offset) })
        
        // 매핑 초기화
        for (index, token) in tokens.enumerated() {
            idToToken[index] = token
            tokenToId[token] = index
        }
        
        // 특수 토큰 추가
        for (token, id) in specialTokens {
            idToToken[id] = token
            tokenToId[token] = id
        }
        
        // 언어 토큰 초기화
        initializeLanguageTokens()
    }
    
    // Codable 요구사항 충족
    private enum CodingKeys: String, CodingKey {
        case tokens
        case specialTokens
        case languageTokens
    }
    
    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tokens = try container.decode([String].self, forKey: .tokens)
        specialTokens = try container.decode([String: Int].self, forKey: .specialTokens)
        tokenToId = Dictionary(uniqueKeysWithValues: tokens.enumerated().map { ($0.element, $0.offset) })
        
        // 매핑 초기화
        for (index, token) in tokens.enumerated() {
            idToToken[index] = token
            tokenToId[token] = index
        }
        
        // 특수 토큰 추가
        for (token, id) in specialTokens {
            idToToken[id] = token
            tokenToId[token] = id
        }
        
        // 언어 토큰 초기화
        if let languageTokens = try? container.decode([String: Int].self, forKey: .languageTokens) {
            self.languageTokens = languageTokens
        } else {
            initializeLanguageTokens()
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(tokens, forKey: .tokens)
        try container.encode(specialTokens, forKey: .specialTokens)
        try container.encode(languageTokens, forKey: .languageTokens)
    }
    
    /// 언어 토큰 초기화
    private func initializeLanguageTokens() {
        // Whisper 모델이 지원하는 99개 언어에 대한 토큰 ID 매핑
        // 실제 Whisper 모델의 언어 토큰 ID와 일치하도록 설정
        let languages = [
            "en", "zh", "de", "es", "ru", "ko", "fr", "ja", "pt", "tr", "pl", "ca", "nl", "ar", "sv", "it", "id", "hi", "fi", "vi",
            "uk", "el", "ms", "cs", "ro", "da", "hu", "ta", "no", "th", "ur", "hr", "bg", "lt", "la", "mi", "ml", "cy", "sk", "te",
            "fa", "lv", "bn", "sr", "az", "sl", "kn", "et", "mk", "br", "eu", "is", "hy", "ne", "mn", "bs", "kk", "sq", "sw",
            "gl", "mr", "pa", "si", "km", "sn", "yo", "so", "af", "oc", "ka", "be", "tg", "sd", "gu", "am", "yi", "lo", "uz",
            "fo", "ht", "ps", "tk", "nn", "mt", "sa", "lb", "my", "bo", "tl", "mg", "as", "tt", "haw", "ln", "ha", "ba",
            "jw", "su"
        ]
        
        // 언어 토큰 ID 시작 값 (Whisper 모델에서는 50258부터 시작)
        let languageTokenStartId = 50258
        
        for (index, language) in languages.enumerated() {
            let tokenId = languageTokenStartId + index
            let languageToken = "<|\(language)|>"
            
            // 언어 토큰 매핑 추가
            languageTokens[language] = tokenId
            
            // 토큰 사전에도 추가
            idToToken[tokenId] = languageToken
            tokenToId[languageToken] = tokenId
        }
    }
    
    /// 텍스트를 토큰으로 변환
    public func encode(_ text: String) -> [Int] {
        // 간단한 구현: 공백으로 분리하고 각 단어를 토큰으로 변환
        // 실제 구현에서는 BPE(Byte Pair Encoding) 또는 WordPiece 등의 알고리즘 사용
        
        var result: [Int] = []
        
        // 특수 문자 처리
        var processedText = text
        for (token, id) in specialTokens {
            if processedText.contains(token) {
                processedText = processedText.replacingOccurrences(of: token, with: " \(token) ")
                result.append(id)
            }
        }
        
        // 단어 분리 및 토큰화
        let words = processedText.split(separator: " ")
        for word in words {
            let wordStr = String(word)
            
            // 특수 토큰인 경우
            if let id = specialTokens[wordStr] {
                result.append(id)
                continue
            }
            
            // 언어 토큰인 경우
            if wordStr.starts(with: "<|") && wordStr.hasSuffix("|>") {
                let langCode = String(wordStr.dropFirst(2).dropLast(2))
                if let id = languageTokens[langCode] {
                    result.append(id)
                    continue
                }
            }
            
            // 일반 토큰인 경우
            if let id = tokenToId[wordStr] {
                result.append(id)
            } else {
                // 알 수 없는 토큰은 문자 단위로 분해
                for char in wordStr {
                    let charStr = String(char)
                    if let id = tokenToId[charStr] {
                        result.append(id)
                    } else {
                        // 알 수 없는 문자는 특수 토큰으로 대체 (실제로는 UNK 토큰 사용)
                        result.append(0)
                    }
                }
            }
        }
        
        return result
    }
    
    /// 토큰을 텍스트로 변환
    public func decode(_ tokens: [Int]) -> String {
        var result = ""
        var skipNext = false
        
        for (i, tokenId) in tokens.enumerated() {
            if skipNext {
                skipNext = false
                continue
            }
            
            // 토큰 ID에 해당하는 텍스트 가져오기
            guard let token = idToToken[tokenId] else {
                continue
            }
            
            // 특수 토큰 처리
            if token.starts(with: "<|") && token.hasSuffix("|>") {
                // 타임스탬프 토큰 등 특수 토큰은 무시
                continue
            }
            
            // 일반 토큰 처리
            if i > 0 && !result.isEmpty && !token.starts(with: "▁") {
                result += token
            } else if token.starts(with: "▁") {
                // Whisper는 공백을 ▁로 표시
                result += " " + token.dropFirst()
            } else {
                result += token
            }
        }
        
        // 후처리: 불필요한 공백 제거 및 문장 정리
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        result = result.replacingOccurrences(of: "  ", with: " ")
        
        return applyPronunciationRules(to: result)
    }
    
    /// 발음 규칙 적용
    private func applyPronunciationRules(to text: String) -> String {
        var result = text
        for rule in pronunciationRules {
            if let regex = try? NSRegularExpression(pattern: rule.pattern) {
                let range = NSRange(result.startIndex..., in: result)
                result = regex.stringByReplacingMatches(
                    in: result,
                    range: range,
                    withTemplate: rule.replacement
                )
            }
        }
        return result
    }
    
    /// 토크나이저 파일 로드
    public static func load(from url: URL) throws -> WhisperTokenizer {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(WhisperTokenizer.self, from: data)
    }
    
    /// 토크나이저 파일 저장
    public func save(to url: URL) throws {
        let data = try JSONEncoder().encode(self)
        try data.write(to: url)
    }
    
    /// 특수 토큰 추가
    /// - Parameters:
    ///   - original: 원본 토큰
    ///   - adjusted: 조정된 토큰
    public func addSpecialToken(_ original: String, _ adjusted: String) {
        if !tokens.contains(adjusted) {
            tokens.append(adjusted)
            tokenToId[adjusted] = tokens.count - 1
            specialTokens[original] = tokens.count - 1
        }
    }
    
    /// 발음 규칙 추가
    /// - Parameters:
    ///   - pattern: 패턴
    ///   - replacement: 대체 텍스트
    public func addPronunciationRule(pattern: String, replacement: String) {
        pronunciationRules.append((pattern: pattern, replacement: replacement))
    }
    
    /// 언어 토큰 가져오기
    /// - Parameter language: 언어 코드
    /// - Returns: 언어 토큰 ID
    public func getLanguageTokenId(_ language: String) -> Int? {
        return languageTokens[language]
    }
    
    /// 언어 토큰 문자열 가져오기
    /// - Parameter language: 언어 코드
    /// - Returns: 언어 토큰 문자열
    public func getLanguageToken(_ language: String) -> String {
        return "<|\(language)|>"
    }
    
    /// 지원하는 모든 언어 코드 가져오기
    /// - Returns: 언어 코드 배열
    public func getSupportedLanguages() -> [String] {
        return Array(languageTokens.keys)
    }
}

extension WhisperTokenizer {
    /// 타임스탬프 토큰 생성
    public func createTimestampToken(seconds: Double) -> String {
        return "<|\(String(format: "%.2f", seconds))|>"
    }
    
    /// 타임스탬프 토큰에서 시간 추출
    public func extractTimestamp(from token: String) -> Double? {
        guard token.starts(with: "<|"), token.hasSuffix("|>") else { return nil }
        let timeStr = token.dropFirst(2).dropLast(2)
        return Double(timeStr)
    }
    
    /// 특수 토큰 여부 확인
    public func isSpecialToken(_ token: String) -> Bool {
        return specialTokens.keys.contains(token)
    }
    
    /// 특수 토큰 ID 가져오기
    public func getSpecialTokenId(_ token: String) -> Int? {
        return specialTokens[token]
    }
    
    /// 언어 토큰 여부 확인
    public func isLanguageToken(_ token: String) -> Bool {
        if token.starts(with: "<|") && token.hasSuffix("|>") {
            let langCode = String(token.dropFirst(2).dropLast(2))
            return languageTokens.keys.contains(langCode)
        }
        return false
    }
} 