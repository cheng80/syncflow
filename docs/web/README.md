# Web 폴더 재사용 가이드 (App Portal + 앱별 페이지)

이 문서는 `docs/web` 폴더를 다른 프로젝트로 그대로 가져가서, 새로운 앱 웹페이지를 추가할 때 지켜야 할 제작 규칙을 정리한 가이드입니다.

---

## 1) 폴더 구조 규칙

`docs/web`는 아래 구조를 기본으로 유지합니다.

```text
docs/web/
  index.html              # 포털 메인 (앱 목록)
  privacy.html            # 포털 자체 개인정보처리방침
  terms.html              # 포털 자체 이용약관
  assets/
    style.css             # 공통 스타일
    i18n.js               # 공통 한/영 전환 + 도메인 표기
  templates/
    app-template/
      index.html          # 앱 소개 템플릿
      privacy.html        # 앱 개인정보처리방침 템플릿
      terms.html          # 앱 이용약관 템플릿
  <app-slug>/             # 앱별 폴더 (예: tagdo, timerpro, habitmate)
    index.html            # 앱 소개/랜딩
    privacy.html          # 앱 개인정보처리방침
    terms.html            # 앱 이용약관
```

핵심 원칙:
- 공통 리소스는 **반드시** `assets/`에 둡니다.
- 앱 페이지는 **반드시 앱 슬러그 폴더**(`<app-slug>`)로 분리합니다.
- 더 이상 `policy/` 같은 공용-앱 혼합 폴더는 만들지 않습니다.

---

## 2) 앱 추가 규칙 (반드시 준수)

### A. 앱 폴더명 규칙
- 소문자 영문 + 숫자 + 하이픈만 사용
- 예: `tagdo`, `habit-tracker`, `timerpro2`

### B. 앱별 필수 파일 3개
- `index.html`
- `privacy.html`
- `terms.html`

### C. 공통 리소스 참조 경로
앱 폴더 내부 파일에서는 다음 경로를 사용:
- CSS: `../assets/style.css`
- JS: `../assets/i18n.js`

포털 루트 파일(`docs/web/*.html`)에서는:
- CSS: `assets/style.css`
- JS: `assets/i18n.js`

---

## 3) 템플릿 사용 방법

새 앱 생성 시 아래 순서로 시작합니다.

### A. 템플릿 위치
- `docs/web/templates/app-template/index.html`
- `docs/web/templates/app-template/privacy.html`
- `docs/web/templates/app-template/terms.html`

### B. 복사 예시
```bash
mkdir -p docs/web/<app-slug>
cp docs/web/templates/app-template/* docs/web/<app-slug>/
```

### C. 필수 치환 토큰
템플릿 내 아래 값을 앱별로 바꿉니다.
- `__APP_NAME__` (앱명)
- `__APP_VERSION__` (버전)
- `__APP_KO_TAGLINE__`, `__APP_EN_TAGLINE__`
- `__APP_KO_DESC__`, `__APP_EN_DESC__`
- `__SUPPORT_EMAIL__`
- `__EFFECTIVE_DATE__`, `__UPDATED_DATE__`
- `__EFFECTIVE_DATE_EN__`, `__UPDATED_DATE_EN__`

---

## 4) 다국어(한/영) 작성 규칙

`assets/i18n.js`는 아래 패턴으로 동작합니다.

### A. 짧은 문구 전환
- `data-ko`, `data-en` 속성 사용

예시:
```html
<h1 data-ko="앱 포털" data-en="App Portal">앱 포털</h1>
```

### B. 긴 본문 전환
- 한국어 블록: `data-ko-display`
- 영어 블록: `data-en-display`

예시:
```html
<article data-ko-display>...한국어 본문...</article>
<article data-en-display style="display:none">...English body...</article>
```

### C. 언어 버튼
- 페이지마다 아래 버튼 유지
```html
<div class="lang-switch">
  <button class="lang-btn active" data-lang="ko">KO</button>
  <button class="lang-btn" data-lang="en">EN</button>
</div>
```

---

## 5) 도메인 표기 규칙

푸터 표기는 아래 형태를 사용합니다:

```html
<p>&copy; 2026 <span data-domain>cheng80.myqnapcloud.com</span>. All rights reserved.</p>
```

설명:
- `i18n.js`가 실행되면 실제 접속 도메인(hostname)으로 자동 치환됩니다.
- 로컬 테스트 시에는 `i18n.js`의 fallback 값이 표시됩니다.

---

## 6) 포털(`index.html`) 관리 규칙

앱 추가 시 아래 2곳을 반드시 수정합니다.

1) 상단 네비게이션 (선택)
- 새 앱 링크 추가 가능

2) 앱 카드 섹션 (필수)
- 새 앱 카드 추가
- 링크는 `./<app-slug>/index.html`, `./<app-slug>/privacy.html`, `./<app-slug>/terms.html` 형식

예시:
```html
<a class="hub-link" href="timerpro/index.html">앱 소개</a>
<a class="hub-link" href="timerpro/privacy.html">개인정보처리방침</a>
<a class="hub-link" href="timerpro/terms.html">이용약관</a>
```

---

## 7) 앱별 정책 작성 규칙

### 개인정보처리방침(`privacy.html`)
- 실제 앱 동작 기준으로 작성
- 권한 항목은 **사용자 동의 받는 권한만** 명시
- 선택 권한이라도 미허용 시 기능 제한이 있으면 반드시 명시

### 이용약관(`terms.html`)
- 서비스 범위, 데이터 책임, 면책, 문의 수단 포함
- 앱명/기능과 1:1로 맞는 문구 사용

---

## 8) 스토어 메타데이터 동기화 규칙

앱 추가/수정 후, 스토어 제출 문서도 함께 수정합니다:
- `docs/STORE_METADATA_PLAY_APPSTORE_2026.md`

수정 항목:
- Privacy URL
- Terms URL
- Support URL
- 앱명/설명/권한 문구

URL 형식:
- `https://<도메인>/web/<app-slug>/privacy.html`
- `https://<도메인>/web/<app-slug>/terms.html`
- `https://<도메인>/web/<app-slug>/index.html`

---

## 9) 새 앱 추가 절차 (체크리스트)

1. [ ] `docs/web/<app-slug>/` 폴더 생성
2. [ ] 템플릿 3개 복사 (`docs/web/templates/app-template/*`)
3. [ ] 경로가 `../assets/style.css`, `../assets/i18n.js`인지 확인
4. [ ] 포털 `docs/web/index.html`에 앱 카드 추가
5. [ ] 푸터/문의 이메일/앱명 오타 점검
6. [ ] 한/영 전환 버튼 정상 동작 확인
7. [ ] 스토어 메타데이터 문서 URL/설명 업데이트
8. [ ] 실제 배포 URL에서 링크 깨짐 확인

---

## 10) 금지 사항

- `assets/` 외 위치에 공통 CSS/JS 중복 생성 금지
- 앱별 폴더 없이 루트에 앱 정책 파일 생성 금지
- 포털 정책과 앱 정책 혼합 금지
- 임시 리다이렉트 파일을 장기 운영 구조로 방치 금지

---

## 11) 권장 운영 팁

- 앱마다 동일한 기본 템플릿을 쓰되, 권한/데이터 처리 문구는 앱별 실제 동작에 맞게 수정
- 포털 카드에 출시 상태 배지(`LIVE`, `BETA`, `COMING SOON`)를 일관되게 사용
- 정책 시행일/수정일은 스토어 제출일과 동기화

