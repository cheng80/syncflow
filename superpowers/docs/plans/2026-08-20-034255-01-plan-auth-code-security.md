# 이메일 인증코드 보안 정책 보강

**Goal:** FastAPI 인증코드 발송·검증이 문서의 재전송, 최신 코드, 시도 횟수 정책대로 동작하게 한다.
**Why planning is required:** 로그인 인증과 외부 SMTP를 변경하는 보안 민감 작업이다.
**Acceptance:** 이메일 형식을 검증하고, 같은 이메일은 60초 내 재발송을 거부하며, 최신 코드만 유효하고 오입력 5회 후 차단되며, 발송 실패 시 새 DB 레코드를 제거한다.

### Outcome 1: 발송 정책 적용
- Work: `fastapi/app/api/auth.py`에서 이메일 검증, 60초 제한, 최신 코드 교체, SMTP 실패 정리를 한 흐름으로 처리한다.
- Verify: `python3 -m unittest discover -s tests -v`

### Outcome 2: 검증 정책 적용
- Work: 최신 인증 레코드를 이메일로 조회하고 해시를 비교해 오입력마다 `attempt_count`를 증가시키며 5회 후 차단한다.
- Verify: `python3 -m unittest discover -s tests -v`

### Outcome 3: 회귀 검증
- Work: API 라우트 로딩과 기존 성공 경로를 확인하고, FastAPI 검증 오류 배열을 Flutter가 안전하게 표시하도록 한 뒤 변경 diff를 검토한다.
- Verify: `python3 -m compileall -q app tests`

### Outcome 4: 재발송 카운트다운
- Work: 재발송 거부 응답의 실제 남은 시간을 Flutter 메모리에서만 카운트다운하고, 만료 전 버튼을 비활성화한다.
- Verify: `flutter test test/api_client_test.dart` 및 `flutter build ios --simulator --debug`
