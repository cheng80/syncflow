# NEW FCM 구현 및 설정 가이드 (공용)

이 폴더는 특정 앱/도메인에 종속되지 않는 **공용 FCM 가이드** 모음입니다.

문서 상태:
- 신규 사용 경로: `docs/NEW-FCM구현 및 설정가이드`
- 기존 문서 보관 경로: `docs/_archive_FCM구현 및 설정 가이드`

검증 기준:
- 공식 문서 반영일: **2026-03-04**
- 기준 소스: Firebase/Google 공식 문서 + Firebase Flutter 공식 패키지 문서

## 문서 구성

1. `01_FCM_iOS_Android_설정_가이드.md`
- Flutter 앱에서 iOS/Android FCM 토큰 발급까지의 공통 설정
- 핵심 코드 블록을 `공용 버전` + `SyncFlow 버전` 쌍으로 제공

2. `02_FCM_토큰_저장소_및_서버_연동_가이드.md`
- 클라이언트 토큰 보관/갱신/서버 동기화 표준
- 핵심 코드 블록을 `공용 버전` + `SyncFlow 버전` 쌍으로 제공

3. `03_FCM_백엔드_푸시_발송_가이드.md`
- 백엔드 이벤트 기반 푸시 발송 파이프라인 가이드
- 핵심 코드 블록을 `공용 버전` + `SyncFlow 버전` 쌍으로 제공

4. `04_FCM_푸시_시스템_다이어그램.md`
- 시스템 흐름/컴포넌트/데이터 흐름 템플릿

## 플레이스홀더 매핑

| Placeholder | 실제 값 예시 |
|---|---|
| `<APP_PACKAGE>` | `com.example.app` |
| `<BACKEND_BASE_URL>` | `https://api.example.com` |
| `<USER_ID>` | `42` |
| `<BOARD_ID>` | `101` |
| `<CARD_ID>` | `555` |

## SyncFlow 예시값

- 앱 패키지/번들 ID: `com.cheng80.syncflow`
- Dart 패키지명(import prefix): `syncflow`
- 앱 표시명: `SyncFlow`
- 기본 API Base URL:
  - Android 에뮬레이터: `http://10.0.2.2:8000`
  - iOS 시뮬레이터/기타: `http://127.0.0.1:8000`
- 현재 REST prefix 예시: `/v1/...`

## 권장 도입 순서

1. `01` 앱 FCM 토큰 발급 성공
2. `02` 토큰 서버 등록/갱신/비활성화 완료
3. `03` 이벤트 기반 푸시 발송 구현
4. `04` 다이어그램/운영 기준 팀 합의

## 공통 완료 기준

- 토큰 발급, 토큰 등록, 이벤트 발송, 딥링크 이동이 E2E로 검증됨
- 특정 도메인(결제/예약 등) 없이 재사용 가능함
