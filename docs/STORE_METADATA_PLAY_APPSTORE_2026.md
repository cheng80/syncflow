# SyncFlow 스토어 등록 메타데이터 (Google Play / Apple App Store)

최종 업데이트: 2026-03-02  
앱: `SyncFlow` (`com.cheng80.syncflow`)

이 문서는 2026-02-17 기준으로 **Google Play / Apple 공식 문서 웹 검증** 후 정리한 등록용 메타데이터입니다.  
목표는 아래 2가지입니다.

1. 심사 시 필요한 **필수 입력 항목** 누락 방지
2. 콘솔에 바로 붙여 넣을 수 있는 **SyncFlow 제출 초안(ko-KR / en-US)** 제공

---

## 1) 공식 문서 기준 필수 항목 (검증 완료)

## A. Google Play (Play Console)

### 1) 메인 스토어 리스팅 필수
- `App name` (최대 30자)
- `Short description` (최대 80자)
- `Full description` (최대 4000자)
- `App icon` (필수, `512 x 512`, 32-bit PNG, 최대 1024KB)
- `Feature graphic` (필수, `1024 x 500`, JPG 또는 24-bit PNG)
- `Screenshots` (게시를 위해 최소 2장, device type별 최대 8장)
- `Contact email` (필수)

### 2) App content/정책 제출 필수
- `Data safety form` (내부 테스트 전용 제외, 사실상 모든 공개/테스트 트랙 앱 필수)
- `Privacy policy URL` (Data safety 제출 및 노출 연계)
- `Ads declaration` (Contains ads 여부)
- `Target audience and content`
- `Content rating`
- `App access` (로그인/제한 기능이 있으면 심사용 접근 정보 필수)

---

## B. Apple App Store (App Store Connect)

### 1) App Information / Platform Version 필수
- `Name` (2~30자)
- `Age Rating` (필수)
- `Primary Category` (필수)
- `Privacy Policy URL` (iOS/macOS 앱 필수)
- `Screenshots` (필수, 디바이스 타입별 1~10장)
- `Description` (필수, 최대 4000자)
- `Keywords` (필수, 최대 100 bytes)
- `Support URL` (필수, 실제 연락 정보로 연결되어야 함)
- `Copyright` (필수)

### 2) App Review Information 필수
- `Contact name`
- `Contact email`
- `Contact phone`
- `Demo account` (로그인 필요 앱인 경우)

### 3) 선택 항목
- `Promotional Text` (최대 170자)
- `Marketing URL`

---

## 2) SyncFlow 공통 입력값

아래는 현재 프로젝트 코드/웹 문서 기준으로 채운 값입니다.

- 앱 이름: `SyncFlow`
- Android package: `com.cheng80.syncflow`
- iOS bundle id: `com.cheng80.syncflow`
- 카테고리: `Productivity`
- 지원 이메일: `cheng80@gmail.com`
- 개인정보처리방침 URL: `https://cheng80.myqnapcloud.com/web/syncflow/privacy.html`
- 이용약관 URL: `https://cheng80.myqnapcloud.com/web/syncflow/terms.html`
- 앱 소개/마케팅 URL: `https://cheng80.myqnapcloud.com/web/syncflow/index.html`
- 앱 버전(현재): `1.0.0+1`

---

## 3) Google Play 제출용 입력안 (ko-KR / en-US)

## A. Product details

### ko-KR
- App name: `SyncFlow`
- Short description (<=80):  
  `소규모 팀을 위한 실시간 경량 협업 칸반 보드 앱`
- Full description (<=4000):

```text
SyncFlow는 2~5인 소규모 팀을 위한 실시간 경량 협업 칸반 보드 앱입니다.

[핵심 기능]
- 보드/컬럼/카드 생성·수정·드래그 이동
- 카드 이동·수정이 즉시 팀원에게 반영되는 실시간 동기화
- 편집 중 겹침 방지
- 지금 접속한 멤버 아바타 표시
- 6자리 초대 코드로 멤버 참가
- 템플릿 기반 빠른 보드 생성
- 라이트/다크/시스템 테마
- 다국어 지원 (ko, en, ja, zh-CN, zh-TW)

[개인정보 및 데이터]
- 이메일 6자리 코드로 로그인, 세션 토큰은 기기에 암호화 저장됩니다.
- 보드·카드 데이터는 서버에 저장되며 협업에 사용됩니다.

[권한 안내]
- 인터넷 연결: 보드 데이터 동기화에 필요합니다.
```

### en-US
- App name: `SyncFlow`
- Short description (<=80):  
  `Real-time lightweight kanban board for small teams.`
- Full description (<=4000):

```text
SyncFlow is a real-time lightweight collaboration kanban board for teams of 2-5 people.

[Key Features]
- Create, edit, and drag cards across columns
- Real-time sync so changes appear instantly for your team
- Prevent edit conflicts when multiple people work at once
- See who's online with member avatars
- 6-digit invite code for member onboarding
- Template-based quick board setup
- Light/Dark/System themes
- Multi-language support (ko, en, ja, zh-CN, zh-TW)

[Privacy and Data]
- Login via 6-digit email code; session token stored encrypted on device.
- Board and card data stored on server for collaboration.

[Permission]
- Internet: required for board data sync.
```

---

## B. Graphics checklist (Play)

### Play 필수/권장 이미지 규격 (픽셀)

| 항목 | 필수 여부 | 규격 |
|---|---|---|
| App icon | 필수 | `512 x 512` PNG (32-bit, alpha), 최대 1024KB |
| Feature graphic | 필수 | `1024 x 500` JPG 또는 24-bit PNG |
| Phone screenshots | 필수 | 최소 2장, 최대 8장/기기타입 |

### Play 스크린샷 실제 제작 해상도 (SyncFlow 권장)

Play는 폭넓은 범위를 허용하므로, 아래 2종만 준비해도 안정적으로 운영 가능합니다.

- 세로 기본본(권장): `1080 x 1920` (9:16)
- 가로 기본본(선택): `1920 x 1080` (16:9)

추가 규칙(공식):
- 최대 한 변 `3840px`
- 긴 변은 짧은 변의 2배 초과 불가

노출 최적화(권장):
- 앱은 `1080px 이상` 스크린샷 4장 이상 권장
- 태블릿 노출을 원하면 태블릿 스크린샷도 별도 업로드 권장

---

## C. App content / Data safety 입력 가이드 (SyncFlow 기준)

> 최종 제출 전에는 포함 SDK의 실제 네트워크 전송 여부를 다시 검증하세요.

- Data collected: `Yes` (이메일, 보드·카드 데이터 등 협업에 필요한 데이터)
- Data shared: `Yes` (보드 멤버 간 공유)
- Privacy policy URL: `https://cheng80.myqnapcloud.com/web/syncflow/privacy.html`
- Ads: `No` (광고 SDK 없음)
- App access: `All functionality requires login` (이메일 코드 로그인 필요, Demo account 제공 권장)
- Target audience and content: 일반 생산성 앱 기준으로 실제 타깃 연령 설정
- Content rating: 설문 기반으로 생성

---

## 4) Apple App Store 제출용 입력안 (ko / en)

## A. App Information

- Name: `SyncFlow` (<=30)
- Subtitle (ko): `실시간 협업 칸반 보드` (<=30)
- Subtitle (en): `Real-time Kanban for Teams` (<=30)
- Primary Category: `Productivity`
- Age Rating: 생산성 앱 기준 설문 응답
- Privacy Policy URL: `https://cheng80.myqnapcloud.com/web/syncflow/privacy.html`

---

## B. Version metadata

### Promotional Text (선택, <=170)
- ko: `소규모 팀을 위한 실시간 칸반 보드. 카드 이동과 수정이 즉시 동기화됩니다.`
- en: `Real-time kanban for small teams. Card moves and edits sync instantly.`

### Description (필수, <=4000)

ko:
```text
SyncFlow는 2~5인 소규모 팀을 위한 실시간 경량 협업 칸반 보드 앱입니다.

주요 기능
- 보드/컬럼/카드 생성·수정·드래그 이동
- 실시간 동기화, 편집 충돌 방지, 접속 멤버 표시, 멤버 초대
- 템플릿 기반 빠른 보드 생성
- 테마, 다국어 지원

개인정보 및 데이터
- 이메일 6자리 코드로 로그인, 세션 토큰은 기기에 암호화 저장됩니다.
- 보드·카드 데이터는 서버에 저장되며 협업에 사용됩니다.

권한
- 인터넷 연결: 보드 데이터 동기화에 필요합니다.
```

en:
```text
SyncFlow is a real-time lightweight kanban board for teams of 2-5 people.

Key features
- Create, edit, and drag cards across columns
- Real-time sync, edit conflict prevention, who's online, member invite
- Template-based quick board setup
- Themes and localization

Privacy and data
- Login via 6-digit email code; session token stored encrypted on device.
- Board and card data stored on server for collaboration.

Permission
- Internet: required for board data sync.
```

### Keywords (필수, <=100 bytes)
- ko 예시: `칸반,협업,보드,실시간,팀,할일,태스크,생산성`
- en 예시: `kanban,collaboration,board,realtime,team,task,todo,productivity`

### Support URL (필수)
- `https://cheng80.myqnapcloud.com/web/syncflow/privacy.html`

### Marketing URL (선택)
- `https://cheng80.myqnapcloud.com/web/syncflow/index.html`

### Copyright
- `2026 KIM TAEK KWON`

---

## C. Screenshot checklist (Apple)

프로젝트 설정 확인 결과:
- `ios/Runner.xcodeproj/project.pbxproj` -> `TARGETED_DEVICE_FAMILY = "1,2"`
- 즉, **SyncFlow는 iPhone + iPad 지원 앱**이며 두 기기군 스크린샷이 모두 필요합니다.

### Apple 스크린샷 필수 규칙

- 포맷: `.jpeg`, `.jpg`, `.png`
- 수량: 디바이스 타입별 `1~10장`
- iPhone용 최소 1장 이상 필수
- iPad 지원 앱은 iPad용 최소 1장 이상 필수

### Apple 실제 제작 해상도 (SyncFlow 준비 기준)

| 기기군 | 준비 권장 해상도(세로) | 비고 |
|---|---:|---|
| iPhone (6.9") | `1320 x 2868` | 최신 대화면 기준, 이 해상도 세트 권장 |
| iPhone (대체) | `1290 x 2796` 또는 `1260 x 2736` | 6.9" 허용 해상도 대체값 |
| iPhone (6.5") | `1284 x 2778` 또는 `1242 x 2688` | 6.9" 미제공 시 사용 |
| iPad (13") | `2064 x 2752` | iPad 지원 앱 권장 기본 |
| iPad (대체) | `2048 x 2732` | 13" 허용 해상도 대체값 |

SyncFlow 권장 최소 세트(실무):
- iPhone 6.9" 세로 `1320 x 2868`로 5장
- iPad 13" 세로 `2064 x 2752`로 5장
- 총 10장(스토어 설명 흐름: 로그인/보드 목록 -> 보드 상세 -> 카드 편집 -> 멤버 초대 -> 설정)

---

## 5) 제출 전 최종 체크리스트

- [x] 앱명/패키지명/Bundle ID 확인 (`SyncFlow`, `com.cheng80.syncflow`)
- [x] 개인정보처리방침/이용약관 URL 운영 확인
- [ ] Play/App Store locale별 텍스트 최종 교정
- [ ] 최신 UI 기준 스크린샷 교체
- [ ] Play Data safety: SDK별 실제 전송 데이터 재검증
- [ ] Apple Support URL에 연락 정보(이메일/전화/주소) 충족 여부 최종 점검
- [ ] App Review 연락처/전화번호/테스트 계정 필요 여부 최종 입력

---

## 6) 공식 문서 출처 (웹 검증 완료)

## Google Play (공식 Help Center)
- Create and set up your app  
  https://support.google.com/googleplay/android-developer/answer/9859152
- Add preview assets to showcase your app  
  https://support.google.com/googleplay/android-developer/answer/9866151
- Provide information for Google Play's Data safety section  
  https://support.google.com/googleplay/android-developer/answer/10787469
- Prepare your app for review  
  https://support.google.com/googleplay/android-developer/answer/9859455

## Apple App Store Connect (공식 Help)
- App information  
  https://developer.apple.com/help/app-store-connect/reference/app-information/app-information/
- Required, localizable, and editable properties  
  https://developer.apple.com/help/app-store-connect/reference/app-information/required-localizable-and-editable-properties/
- Platform version information  
  https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/
- Screenshot specifications  
  https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/
