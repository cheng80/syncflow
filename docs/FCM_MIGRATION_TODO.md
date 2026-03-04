# FCM 문서 공용화 및 SyncFlow 마이그레이션 TODO

## 목적

- 기존 `docs/FCM구현 및 설정 가이드` 문서를 특정 프로젝트 의존성 없이 재사용 가능한 공용 문서로 정리
- 공용 문서를 기준으로 SyncFlow에 필요한 최소 FCM 도입 작업을 단계적으로 적용
- `todo.md`의 2단계(FCM 연계) 착수 전에 선행 정리 완료

---

## 0) 검토 결과 요약 (2026-03-04)

### 문서 경로 상태 (2026-03-04)

- 신규 공용 문서(사용): `docs/NEW-FCM구현 및 설정가이드`
- 기존 문서(보관): `docs/_archive_FCM구현 및 설정 가이드`

### 현재 프로젝트(SyncFlow) 적용 가능성

- **결론: 부분 적용 가능 (즉시 적용 불가)**
- 이유:
  - 현재 `pubspec.yaml`에 `firebase_core`, `firebase_messaging` 의존성이 없음
  - `lib`/`fastapi`에 FCM 토큰 발급/등록/발송 구현이 없음
  - 기존 FCM 문서 다수는 `table_now_app`, `customer_seq`, `reserve/payment` 도메인에 고정

### 문서 공용화 관점의 문제

- 프로젝트 고유 경로/식별자 다수 하드코딩
- 도메인 예시가 예약/결제 중심으로 편향
- 일부 링크/참고 파일이 현재 폴더 기준으로 누락되거나 불명확
- "완료된 작업" 체크리스트가 특정 시점 상태를 공용 문서에 섞어 유지보수 비용 증가

---

## 1) 공용화 리팩터링 TODO (문서 자체 정비)

### 1-1. 문서 구조 재편

- [ ] FCM 문서 상단에 공용 템플릿 선언 추가
  - [ ] 프로젝트 불문 공통 파트
  - [ ] Flutter 앱 파트
  - [ ] 백엔드 파트 (FastAPI/Node/Spring 등 대체 가능 표기)
- [ ] "현재 프로젝트 완료 상태" 섹션을 분리 또는 제거
- [ ] 문서 간 의존 관계를 `README` 인덱스로 재정리

### 1-2. 프로젝트 종속 텍스트 제거

- [ ] `table_now_app` 패키지명 → `<your_app_package>` 플레이스홀더 치환
- [ ] `customer_seq`, `reserve_seq`, `payment_seq` → `user_id`, `entity_id` 등 범용 명칭으로 치환
- [ ] `toss_result_page.dart`, `reserve.py`, `payment.py` 같은 도메인 경로를 예시 경로로 일반화
- [ ] `POST /api/customer/{customer_seq}/...` → 범용 토큰/푸시 API 규격으로 정리

### 1-3. 예시 코드 범용화

- [ ] 코드 샘플에 "필수/선택" 라벨 추가
- [ ] 클라이언트/서버 예시를 "기본형" + "도메인 확장형"으로 분리
- [ ] 데이터 페이로드 스키마를 범용 이벤트 타입 중심으로 재정의
  - [ ] `mention_created`
  - [ ] `card_assignee_changed`
  - [ ] `card_status_changed`
  - [ ] `board_invitation_updated`

### 1-4. 정확성/유지보수성 보강

- [ ] 각 문서에 "검증 기준(DoD)" 추가
  - [ ] 토큰 발급 확인
  - [ ] 서버 등록 확인
  - [ ] 이벤트 발송 확인
  - [ ] 딥링크 이동 확인
- [ ] 깨진 참조 링크 정리 및 실제 파일 존재 확인
- [ ] "플랫폼/버전별 주의사항"을 별도 섹션으로 통합

---

## 2) SyncFlow 적용 TODO (문서 정비 후 구현)

### 2-1. Flutter 앱

- [ ] `pubspec.yaml` 의존성 추가
  - [ ] `firebase_core`
  - [ ] `firebase_messaging`
  - [ ] 필요 시 `flutter_local_notifications`
- [ ] `main.dart` Firebase 초기화 + FCM 초기화 루틴 추가
- [ ] `FCMNotifier`(또는 동등 provider) 생성
  - [ ] 권한 요청
  - [ ] 토큰 발급/갱신 리스너
  - [ ] 포그라운드 알림 처리
- [ ] 푸시 탭 시 `boardId/cardId/eventType` 기반 라우팅 구현

### 2-2. FastAPI 서버

- [ ] `push_tokens` 저장 스키마 확정 (`todo.md`와 정합)
- [ ] 토큰 등록/갱신/비활성화 API 구현
  - [ ] 로그인 시 등록
  - [ ] 토큰 갱신 시 업데이트
  - [ ] 로그아웃 시 비활성화
- [ ] 이벤트 -> 수신자 결정 -> FCM 발송 파이프라인 구현
- [ ] 실패 재시도/중복 방지 키 설계 반영

### 2-3. 트리거 우선순위 (todo.md 정렬 기준)

- [ ] 멘션됨
- [ ] 내 담당 카드 상태 변경
- [ ] 보드 초대 수락/실패

---

## 3) 완료 기준 (이 문서 기준)

- [ ] 기존 FCM 4개 문서가 프로젝트 고유명 없이 읽혀야 함
- [ ] 신규 프로젝트에서 문서만 보고 "토큰 등록 + 1개 이벤트 푸시 + 딥링크 이동" 재현 가능
- [ ] SyncFlow에서는 `todo.md` 2-1의 FCM 항목 착수 전, 본 문서 1번 섹션이 모두 완료 상태여야 함
- [x] 기존 FCM 문서는 삭제 대신 archive 경로로 보관 전환

---

## 4) 작업 순서 제안

1. 본 문서 `1) 공용화 리팩터링` 완료
2. 기존 FCM 문서 4개 리라이트/참조 정리
3. `todo.md` 2-1의 FCM 토큰/API 작업 착수
4. 멘션/담당자 이벤트 푸시 연결
5. QA 체크리스트로 검증 후 `todo.md` 진행
