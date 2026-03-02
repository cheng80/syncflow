# SyncFlow 이메일 서비스 설정 가이드

SyncFlow 로그인 인증 코드 발송을 위한 SMTP 설정 방법입니다.

**대상**: SyncFlow (소규모 팀 협업 칸반 앱)  
**갱신일**: 2026-03-02

---

## ⚠️ 중요: 팀 개발 환경

**각 개발자는 자신의 로컬 환경에 `.env` 파일을 생성해야 합니다.**

- `.env` 파일은 **Git에 커밋하지 않습니다** (보안상 이유)
- 각 팀원은 자신의 이메일 계정과 앱 비밀번호를 사용합니다
- `.env.example` 파일을 참고하여 자신의 `.env` 파일을 만드세요
- 프로덕션 환경에서는 서버 관리자가 별도로 설정합니다

---

## 1. 환경변수 설정 파일 생성

`fastapi` 폴더에 `.env` 파일을 생성하세요.

### 1.1 .env 파일 생성

`fastapi/.env.example` 파일을 참고하여 `fastapi/.env` 파일을 만드세요:

```bash
cd fastapi
cp .env.example .env
```

**중요 사항:**
- `.env` 파일은 **각 개발자의 컴퓨터에만 존재**합니다
- Git에 커밋하지 마세요 (이미 `.gitignore`에 포함됨)
- 팀원들은 각자 `.env.example`을 복사하여 자신의 설정으로 변경합니다

### 1.2 .env 파일 내용 수정

`.env` 파일을 열어서 실제 값으로 변경하세요:

```env
# SMTP 서버 호스트 (Gmail 사용 시: smtp.gmail.com)
SMTP_HOST=smtp.gmail.com

# SMTP 포트 (Gmail 사용 시: 587)
SMTP_PORT=587

# 발신자 이메일 주소 (Gmail 계정)
SMTP_USER=your-email@gmail.com

# 발신자 비밀번호 (Gmail 앱 비밀번호)
SMTP_PASSWORD=your-16-digit-app-password

# 발신자 표시 이메일 (받는 사람에게 표시될 이메일)
FROM_EMAIL=noreply@syncflow.app

# 발신자 표시 이름 (받는 사람에게 표시될 이름)
FROM_NAME=SyncFlow
```

---

## 2. Gmail 앱 비밀번호 생성 방법

Gmail을 사용하는 경우, 앱 비밀번호를 생성해야 합니다.

### 2.1 2단계 인증 활성화 (필수)

**⚠️ 중요**: 앱 비밀번호를 생성하려면 먼저 2단계 인증을 활성화해야 합니다.

1. [Google 계정 설정](https://myaccount.google.com/) 접속
2. 왼쪽 메뉴에서 **"보안"** 클릭
3. **"2단계 인증"** 섹션에서 **"2단계 인증 사용"** 클릭
4. 안내에 따라 2단계 인증 설정 완료

**2단계 인증 활성화 확인:**
- 2단계 인증이 활성화되면 "앱 비밀번호" 옵션이 나타납니다

### 2.2 앱 비밀번호 생성

다음 링크로 직접 이동하세요:

```
https://myaccount.google.com/apppasswords
```

#### 앱 비밀번호 생성 단계

1. **"앱 선택"** 드롭다운에서 **"기타(맞춤 이름)"** 선택
2. 이름 입력 (예: "SyncFlow Email Service" 또는 "SyncFlow SMTP")
3. **"생성"** 버튼 클릭
4. 생성된 **16자리 비밀번호**가 표시됩니다
5. **비밀번호를 즉시 복사** (한 번만 표시되므로 주의!)
6. `.env` 파일의 `SMTP_PASSWORD`에 붙여넣기

**⚠️ 중요 사항:**
- 앱 비밀번호는 **한 번만 표시**되므로 반드시 복사해두세요!

---

## 3. 다른 이메일 서비스 사용하기

Gmail 외의 다른 이메일 서비스를 사용할 수도 있습니다.

### 3.1 네이버 메일

```env
SMTP_HOST=smtp.naver.com
SMTP_PORT=587
SMTP_USER=your-email@naver.com
SMTP_PASSWORD=your-password
```

### 3.2 Outlook/Hotmail

```env
SMTP_HOST=smtp-mail.outlook.com
SMTP_PORT=587
SMTP_USER=your-email@outlook.com
SMTP_PASSWORD=your-password
```

### 3.3 SendGrid (전문 이메일 서비스)

```env
SMTP_HOST=smtp.sendgrid.net
SMTP_PORT=587
SMTP_USER=apikey
SMTP_PASSWORD=your-sendgrid-api-key
```

---

## 4. 설정 확인

### 4.1 .env 파일 위치 확인

`.env` 파일은 반드시 `fastapi` 폴더 안에 있어야 합니다:

```
fastapi/
  ├── .env          ← 여기에 위치
  ├── app/
  │   ├── main.py
  │   └── ...
  └── ...
```

### 4.2 .gitignore 확인

`.env` 파일은 절대 Git에 커밋하지 마세요!

---

## 5. 테스트

### 5.1 서버 실행

```bash
cd fastapi
python3 -m uvicorn app.main:app --reload
```

### 5.2 이메일 인증 테스트

1. Flutter 앱 실행
2. 로그인 화면에서 이메일 입력
3. "인증 코드 받기" 클릭
4. 입력한 이메일로 인증 코드가 발송되는지 확인

---

## 6. 문제 해결

### 6.1 "이메일 서비스가 설정되지 않았습니다" 오류

- `.env` 파일이 `fastapi` 폴더에 있는지 확인
- `.env` 파일의 변수명이 정확한지 확인 (대문자)
- 서버를 재시작했는지 확인

### 6.2 "이메일 발송에 실패했습니다" 오류

- Gmail 사용 시: 앱 비밀번호를 사용하고 있는지 확인 (일반 비밀번호 X)
- 2단계 인증이 활성화되어 있는지 확인
- SMTP_HOST, SMTP_PORT가 올바른지 확인

### 6.3 Gmail "보안 수준이 낮은 앱의 액세스" 오류

- 앱 비밀번호 사용 (권장)

---

## 변경 이력

- **2026-03-02**: SyncFlow용으로 갱신
  - Habit App → SyncFlow
  - FROM_NAME: "SyncFlow", 앱 비밀번호 이름 업데이트

- **2026-02-15**: 습관 앱용
- **2026-01-15**: 초기 문서 작성
