# TODO - 협업 기능 확장 및 FCM 연계

## 진행 전략

- **1단계**: 멘션(@user) + 카드 단위 완료 체크 → **완료**
- **2단계**: FCM·알림 고도화, 코멘트 등 — **2-1(클라이언트 FCM·토큰·멘션/담당 푸시 경로)은 대부분 반영됨** (미완은 아래 체크리스트)
- **FCM 문서 공용화**: `docs/FCM_MIGRATION_TODO.md` — 문서 정비 항목, **앱 2-1 구현과 완전 선행 아님** (병행 가능). (해당 문서 §0 시점 스냅샷과 달리 **현재 클라이언트는 `firebase_core`/`firebase_messaging` 사용 중** — 문서 본문 점검 시 참고)
- **게스트 모드·온보딩**: 별도 플랜 — `docs/syncflow/게스트_모드_구현_플랜.md` (루트 본 문서의「게스트 모드 & Import API」마일스톤)

---

## 현재 상태 요약

- 권한 모델: `board owner`만 존재
- 담당자(assignee): 도입 완료 (담당자 선택 UI, 담당자별 필터)
- 멘션(@mention): 파싱/동기화 + 인앱 UI(@Me 배지, 멘션만 보기, 전체/완료/미완료 필터) 구현됨
- 카드 단위 완료: `status(active/done)` + 상세/타일 체크 UI 구현됨, 완료 카드도 이동 가능
- FCM 클라이언트 구조: `main.dart` 비대화 해소를 위해 `lib/vm/fcm_notifier.dart`로 분리 완료 (Riverpod Notifier 기반)
- 포그라운드 푸시: `FirebaseMessaging.onMessage` + `flutter_local_notifications` 경로 적용 완료 (iOS/Android 공통)
- FCM 문서: `docs/NEW-FCM구현 및 설정가이드`를 Riverpod 기본 전제로 재정비 완료 (2026-03-05)
- 세분화 알림 기준: 부족 (설정 UI·서버 정책 미도입)
- **푸시 기본 동작(E2E)**: 멘션·담당자(assignee) 변경 시 **실제 수신 확인 완료** (콘솔 테스트 외 앱 시나리오)
- 그 외 이벤트(초대 등)·딥링크·알림 on/off는 여전히 제한적
- **게스트 모드**(이메일 없이 로컬 보드, 계정 게이트 후 서버): **미구현** — 세부는 `docs/syncflow/게스트_모드_구현_플랜.md`

---

## 1단계: 멘션 + 카드 단위 완료 체크

### 멘션(@user)

- [x] 카드 멘션 도입 (`@user`)
- [x] 멘션 파싱 API
- [x] 카드 상세: 멘션 입력 UX
- [x] 저장형 전환: `card_mentions` 테이블 설계/추가
- [x] 저장형 전환: 카드 생성/수정 시 멘션 동기화(upsert/delete)
- [x] 저장형 전환: 보드 상세/WS 응답은 저장 데이터 기준으로 제공
- [x] 저장형 전환: 레거시 호환 fallback(파싱) 유지 + 회귀 검증

### 멘션 수신 UI (FCM 없음, 인앱)

- [x] 카드 타일: 내 멘션 `@Me` 배지
- [x] 보드 상세: `멘션만 보기` 필터 토글
- [x] 카드 상세: 내 멘션 텍스트 하이라이트
- [x] `CARD_UPDATED` 수신 시 멘션 표시 즉시 반영 검증

### 카드 단위 완료 체크

- [x] 카드 `status`(active/done) 활용한 완료 토글
- [x] 카드 상세/타일: 완료 체크 UI
- [x] WebSocket `CARD_UPDATED`로 status 동기화

### 1단계 완료 후

- [x] 멘션 수신 UI + 멘션 영구 저장까지 완료 시 2단계로 진행

---

## 게스트 모드 & Import API (별도 세부 플랜)

> **세부 체크리스트**: `docs/syncflow/게스트_모드_구현_플랜.md`  
> **정책 요약**: 게스트 로컬 보드 개수 제한 없음 · 신규 진입 게스트/로그인 이원 · `has_ever_logged_in` 시 로그인 우선 · 로그아웃은 로그인 화면만(A) · 로컬→서버는 `POST /v1/boards/import`(트랜잭션·idempotency).

### 마일스톤 (여기서만 완료 여부 관리)

- [x] **M1** Flutter: 진입 라우팅 / `has_ever_logged_in` / 게스트·환영 화면 / 게스트 시 FCM 미초기화 (명시적 `AppMode` enum은 미도입, 회귀 QA 권장)
- [ ] **M2** Flutter: 로컬 보드 저장소 + 게스트 목록·상세(WS·REST 분리)
- [ ] **M3** Flutter: 계정 필요 다이얼로그 + `pending_intent` + 초대·참가·서버 보드 생성 등 게이트
- [ ] **M4** FastAPI: `POST /v1/boards/import` 트랜잭션 + `client_board_uuid` idempotent
- [ ] **M5** Flutter: 로그인 직후 import·검증 후 로컬 정리·온라인 전환
- [ ] **M6** i18n · QA · 앱 심사 Review Notes 반영

---

## 2단계: 고도화 (FCM, 역할, 코멘트 등)

### 목표

- 푸시를 "보내기 위한 푸시"가 아니라, 실제 행동 유도가 되는 이벤트 중심으로 설계
- 현재 구조를 크게 깨지 않으면서 단계적으로 도입

### 우선순위 2-1 (FCM 최소 실효성 확보)

- [x] 카드 담당자(assignee) 도입
- [x] Android 에뮬레이터 FCM 토큰 발급 및 Firebase 테스트 메시지 수신 확인 (2026-03-04)
- [x] iOS 실기기 APNs Key 업로드 및 FCM 토큰 발급 확인 (2026-03-04)
- [x] iOS 실기기 Firebase 콘솔 테스트 푸시 수신 확인 (2026-03-04)
- [x] `permission_handler` 알림 권한 설정/코드 경로 점검 및 반영 (2026-03-04)
- [x] 알림 권한 영구 거부 시 시스템 설정 이동(`openAppSettings`) 처리 (2026-03-04)
- [x] 설정 앱 복귀 시 권한 재확인 및 FCM 토큰 재동기화 처리 (2026-03-04)
- [x] 포그라운드 푸시 수신 시 로컬 알림 표출 적용 (`onMessage` -> local notification, 2026-03-05)
- [x] Android 포그라운드 알림 채널 보강 (`syncflow_foreground_push_v2`, 2026-03-05)
- [ ] 기본 알림 설정 도입
  - [ ] 멘션만
  - [ ] 내 담당 카드만
  - [ ] 모두(중요 이벤트)
- [x] FCM 토큰 등록/갱신 API
  - [x] 로그인 시 등록
  - [x] 토큰 갱신 시 업데이트
  - [x] 로그아웃 시 해제

**푸시 트리거(우선)**

- [x] 멘션됨 (서버 트리거 구현: `cards` create/update 시 신규 멘션 대상 발송)
- [x] 멘션 푸시 **수신 검증** (타 사용자가 멘션 시 수신 확인)
- [x] 내 담당 카드 상태 변경 (서버 트리거 구현: `assignee_id` 변경 시 신규 담당자 발송)
- [x] 담당자 지정 푸시 **수신 검증** (assignee 변경 시 수신 확인)
- [ ] 보드 초대 수락/실패

**구조/문서 정리 (추가)**

- [x] FCM 로직을 Riverpod Notifier(`fcm_notifier`)로 분리 (2026-03-05)
- [x] 앱 부팅 시 `AppBootstrap`에서 FCM 초기화 1회 트리거 (2026-03-05)
- [x] NEW-FCM 문서(01/02/03/04/README) 최신 구조 반영 및 Riverpod 기준 명시 (2026-03-05)

### 우선순위 2-2 (협업 정확도 향상)

- [ ] 카드 코멘트 기능
- [ ] 카드 활동 로그(누가/언제/무엇을)
- [ ] 알림 읽음 처리(배지 카운트 정리)

**푸시 트리거(확장)**

- [ ] 내 코멘트에 답글
- [ ] 내가 생성한 카드가 완료/반려됨

### 우선순위 2-3 (노이즈 제어/운영)

- [ ] 묶음 알림(집계) 정책
  - [ ] 5~15분 이벤트 집계
  - [ ] 동일 카드 이벤트 병합
- [ ] 무음 시간대(Do Not Disturb) 정책
- [ ] 재전송/중복 방지 키(idempotency key)
- [ ] 실패 재시도 및 DLQ(서버)

### 우선순위 2-4 (역할/권한, 후순위)

- [ ] 보드 멤버 역할 도입 (`owner`, `editor`, `viewer`)
- [ ] 권한 변경됨 푸시 트리거

---

## 데이터 모델 초안

- [ ] `board_members` 확장: `role`, `joined_at` (2-4 후순위)
- [x] `cards` 확장: `assignee_id`
- [x] `card_mentions` 테이블 (card_id, mentioned_user_id, source_token, created_at)
- [ ] `card_comments` 테이블
- [ ] `notifications` 테이블
  - [ ] `type`, `target_user_id`, `board_id`, `card_id`, `is_read`, `created_at`
- [x] `push_tokens` 테이블
  - [x] `user_id`, `platform`, `token`, `updated_at`, `is_active`
  - [x] `device_id`, `app_version`, `created_at` (확장 반영)

---

## API 작업 리스트

- [x] 멘션 파싱 API (1단계)
- [x] 멘션 영구 저장 API/스키마 정리 (1단계)
- [x] 멘션 조회 API/응답을 저장형 기준으로 통일 (1단계)
- [x] 담당자 지정/해제 API
- [ ] 알림 설정 조회/수정 API
- [ ] 알림 목록/읽음 처리 API
- [x] FCM 토큰 등록/삭제 API (`/v1/push-tokens`, 2026-03-04)
- [ ] 보드 일괄 import API (`POST /v1/boards/import` 가칭, 게스트→인증 마이그레이션) — 플랜: `docs/syncflow/게스트_모드_구현_플랜.md`

---

## 앱(Flutter) 작업 리스트

- [x] 카드 상세: 멘션 입력 UX (1단계)
- [x] 카드 타일: 내 멘션 배지 표시 (1단계 후속)
- [x] 보드 상세: 멘션만 보기 필터 (1단계 후속)
- [x] 카드 상세: 내 멘션 하이라이트 (1단계 후속)
- [x] 카드 상세: 담당자 선택 UI
- [x] 카드 상세/타일: 완료 체크 UI (1단계)
- [x] FCM 초기화/권한/토큰갱신/포그라운드수신 로직 분리 (`lib/vm/fcm_notifier.dart`, 2026-03-05)
- [x] 앱 시작 시 FCM 초기화 트리거 (`AppBootstrap`, 2026-03-05)
- [ ] 게스트 모드·온보딩·로컬 보드·import 마이그레이션 — `docs/syncflow/게스트_모드_구현_플랜.md` (마일스톤은 본 문서「게스트 모드 & Import API」)
- [ ] 설정 화면: 알림 수신 기준/시간대
- [ ] 푸시 탭 딥링크 라우팅
  - [ ] `boardId`, `cardId`, `eventType` 처리

---

## 서버(FastAPI) 작업 리스트

- [ ] 이벤트 발생 지점 표준화 (생성/수정/이동/완료/댓글/멘션)
- [x] FCM 발송 서비스 분리 (`fastapi/app/utils/push_service.py`, 2026-03-05)
- [x] 이벤트 -> 수신자 결정 -> 전송 파이프라인 1차 구현 (멘션/담당자 변경 경로, 2026-03-05)
- [ ] 감사 로그/모니터링 추가

---

## 완료 기준(Definition of Done)

- [x] 멘션/담당자 기반 푸시 **기본 수신·동작** 확인 (실사용 시나리오)
- [ ] 멘션/담당자 푸시 **수신 옵션·노이즈 제어**(설정·집계 등) 반영 후 재검증
- [ ] 중복/노이즈 알림 비율이 목표 이하
- [ ] 푸시 탭 시 해당 보드/카드로 100% 이동
- [ ] 설정 변경 즉시 수신 정책 반영
