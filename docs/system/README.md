# 시스템 구성도

SyncFlow 앱의 시스템 아키텍처. **PlantUML** 문법으로 작성됨.

## 구성 요소

| 구성 요소 | 기술 | 설명 |
|-----------|------|------|
| **APP** | Flutter, Riverpod | 협업 칸반 보드 앱, 상태 관리 |
| **GetStorage** | get_storage | 앱 설정 (테마, locale, wakelock 등) |
| **SecureStorage** | flutter_secure_storage | 세션 토큰 암호화 저장 |
| **Firebase FCM** | firebase_messaging | 푸시 토큰 발급/수신 |
| **Local Notifications** | flutter_local_notifications | 포그라운드 알림 배너 표시 |
| **FastAPI** | Python | REST API + WebSocket |
| **MySQL** | pymysql | 서버 DB (users, sessions, boards, columns, cards, card_mentions, push_tokens) |

## API 엔드포인트

| 구분 | 경로 | 설명 |
|------|------|------|
| REST | /v1/auth | 인증 (send-code, verify, logout) |
| REST | /v1/boards | 보드 CRUD, 컬럼, 초대 |
| REST | /v1/cards | 카드 CRUD |
| REST | /v1/push-tokens | FCM 토큰 업서트/비활성화 |
| WebSocket | /ws | 실시간 동기화 (CARD_MOVE, CARD_UPDATE 등) |

## 렌더링 방법

- VSCode: PlantUML 확장 (jebbs.plantuml) → `Alt+D` 미리보기
- 온라인: [plantuml.com/plantuml](https://www.plantuml.com/plantuml/uml/)
- CLI: `plantuml system.puml` → PNG 생성
