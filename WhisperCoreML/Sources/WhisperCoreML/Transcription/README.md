# Transcription

이 폴더는 음성 인식(Speech-to-Text) 및 변환 관련 기능을 포함합니다.

## 파일 목록

- **TranscriptionOptions.swift**: 음성 변환 옵션 및 설정을 정의합니다.
- **TranscriptionResult.swift**: 음성 변환 결과 구조체를 정의합니다.
- **RealtimeTranscriber.swift**: 실시간 음성 인식 기능을 제공합니다.
- **RealtimeConfiguration.swift**: 실시간 음성 인식 설정을 정의합니다.
- **BatchProcessor.swift**: 여러 오디오 파일을 일괄 처리하는 기능을 제공합니다.

## 역할

Transcription 모듈은 다음과 같은 역할을 담당합니다:

1. 오디오 파일에서 텍스트 추출
2. 실시간 음성 인식
3. 배치 처리 및 진행 상황 추적
4. 변환 옵션 관리
5. 변환 결과 처리 및 포맷팅

## 사용 방법

이 모듈은 파일 기반 변환과 실시간 변환 두 가지 주요 사용 방식을 지원합니다:

1. **파일 기반 변환**: `WhisperModel.transcribe()` 메서드를 사용하여 오디오 파일을 텍스트로 변환합니다.
2. **실시간 변환**: `RealtimeTranscriber` 클래스를 사용하여 마이크 입력을 실시간으로 텍스트로 변환합니다.
3. **배치 처리**: `BatchProcessor` 클래스를 사용하여 여러 오디오 파일을 일괄 처리합니다. 