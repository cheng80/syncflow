# 시스템 구성도

HabitCell 앱의 시스템 아키텍처. **PlantUML** 문법으로 작성됨.

## 구성 요소

| 구성 요소 | 기술 | 설명 |
|-----------|------|------|
| **APP** | Flutter, Riverpod | 습관 추적 앱, 상태 관리 |
| **SQLite** | sqflite | 로컬 DB (categories, habits, logs, heatmap) |
| **GetStorage** | get_storage | 앱 설정 (테마, locale, 백업 설정 등) |
| **Notification** | flutter_local_notifications | Pre-reminder, 마감 알림 |
| **FastAPI** | Python | 백업/복구 REST API |
| **MySQL** | pymysql | 서버 DB (devices, backups, email_verifications) |

## 렌더링 방법

- VSCode: PlantUML 확장 (jebbs.plantuml) → `Alt+D` 미리보기
- 온라인: [plantuml.com/plantuml](https://www.plantuml.com/plantuml/uml/)
- CLI: `plantuml system.puml` → PNG 생성
