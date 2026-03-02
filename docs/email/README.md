# SyncFlow 이메일 인증 문서

SyncFlow 앱의 이메일 기반 로그인 인증 관련 문서 모음입니다.

---

## 문서 목록

| 문서 | 설명 |
|------|------|
| [SyncFlow_이메일_로그인_구현_가이드.md](./SyncFlow_이메일_로그인_구현_가이드.md) | 이메일 6자리 코드 로그인 전체 구현 가이드 (DB, API, Flutter) |
| [SyncFlow_이메일_서비스_설정_가이드.md](./SyncFlow_이메일_서비스_설정_가이드.md) | SMTP 설정, Gmail 앱 비밀번호 생성 방법 |
| [SyncFlow_인증코드와_세션_설명.md](./SyncFlow_인증코드와_세션_설명.md) | 인증 코드, code_hash, session_token 상세 설명 |

---

## 빠른 참조

### API 엔드포인트
- `POST /v1/auth/send-code` - 인증 코드 발송
- `POST /v1/auth/verify` - 코드 검증 → session_token 반환
- `POST /v1/auth/logout` - 세션 폐기

### 주요 파일
- **백엔드**: `fastapi/app/api/auth.py`, `fastapi/app/utils/email_service.py`
- **프론트엔드**: `lib/view/auth/login_screen.dart`, `lib/util/session_secure_storage.dart`

### 관련 설계 문서
- [미니멀_협업_칸반_앱_계정_인증_아키텍처_설계서_v1.md](../syncflow/미니멀_협업_칸반_앱_계정_인증_아키텍처_설계서_v1.md)
