# 이메일 인증코드 발송 실패 수정

**Goal:** iOS 시뮬레이터 로그인 화면에서 인증코드 요청이 FastAPI에 도달하고 이메일 발송 성공 응답을 받게 한다.
**Why planning is required:** 계정 인증 경로와 외부 SMTP 발송을 함께 다루는 보안 민감 변경이다.
**Acceptance:** 실패 원인을 재현하고 최소 수정한 뒤, Flutter iOS 빌드와 FastAPI 인증코드 요청을 검증하며 실제 메일 발송은 사용자가 지정한 주소에만 수행한다.

### Outcome 1: 실패 지점 확정
- Work: FastAPI 상태·앱 API 주소·iOS 빌드 로그를 확인해 Firebase, 네트워크, SMTP 중 최초 실패 지점을 특정한다.
- Risks/open questions: 실제 수신 주소는 임의로 선택하지 않는다.
- Verify: `curl http://127.0.0.1:8000/health` 및 `flutter build ios --simulator --debug`

### Outcome 2: 최소 수정 및 회귀 방지
- Work: iOS 배포 대상을 Firebase 요구사항과 맞추고 생성물 분석을 제외하며, 로그인 성공 후 폐기된 화면의 상태 갱신을 막는다.
- Verify: 원인별 집중 테스트와 `flutter analyze`

### Outcome 3: 최종 동작 검증
- Work: FastAPI 요청 성공, SMTP 발송 호출, iOS 시뮬레이터 실행 가능 여부를 확인한다.
- Verify: `python3 -m compileall -q app`, FastAPI 집중 테스트, `flutter build ios --simulator --debug`
