# Models

이 폴더는 Whisper 모델 관리 및 처리와 관련된 구성 요소를 포함합니다.

## 파일 목록

- **ModelManager.swift**: 모델 다운로드, 캐싱, 로드 등 모델 생명주기 관리를 담당합니다.
- **WhisperModel.swift**: Whisper 모델 클래스로, 모델 로드 및 추론 기능을 제공합니다.
- **WhisperModelType.swift**: 지원되는 Whisper 모델 타입(tiny, base, small, medium, large 등)을 정의합니다.

## 역할

Models 모듈은 다음과 같은 역할을 담당합니다:

1. 모델 다운로드 및 캐싱
2. 모델 로드 및 초기화
3. 모델 추론 및 결과 처리
4. 모델 메타데이터 관리
5. 디스크 공간 관리

## 오프라인 사용

모델이 이미 다운로드되어 있다면 오프라인에서도 사용 가능합니다. `ModelManager`는 모델 로드 시 로컬 파일을 우선적으로 확인하며, 네트워크 연결은 모델 다운로드 시에만 필요합니다. 