# Theme 마이그레이션 계획

habit_app의 기존 theme 구조를 custom_test_app 방식으로 마이그레이션하는 계획입니다.

---

## 1. 현재 vs 목표 구조 비교

### 1.1 현재 habit_app (제거 대상)

| 파일 | 역할 |
|------|------|
| `config_ui.dart` | UI 상수 (모서리, 패딩, 그림자, 애니메이션, 타이포, 습관 카드 그리드 등) |
| `app_colors.dart` | library export + AppColors (light/dark 팔레트) |
| `app_color_scheme.dart` | AppColorScheme (CommonColorScheme 래퍼) |
| `common_color_scheme.dart` | CommonColorScheme (시맨틱 색상 정의) |
| `palette_context.dart` | `context.palette` → AppColorScheme 확장 |

### 1.2 목표 custom_test_app 방식

| 파일 | 역할 |
|------|------|
| `theme_provider.dart` | InheritedWidget 기반 테마 모드 관리 |
| `app_theme_colors.dart` | Brightness 기반 static 메서드 + `context.appTheme` 확장 |
| `README.md` | 사용 문서 |

---

## 2. 주요 차이점 분석

### 2.1 색상 API

| 구분 | habit_app (현재) | custom_test_app (목표) |
|------|------------------|------------------------|
| 접근 방식 | `context.palette` → 객체 getter | `context.appTheme` 또는 `AppThemeColors.xxx(context)` |
| 예시 | `p.background`, `p.textMeta` | `p.background`, `AppThemeColors.textPrimary(context)` |

### 2.2 habit_app 전용 색상 (AppThemeColors에 없음)

custom_test_app의 `AppThemeColors`에는 다음 색상이 없습니다. 마이그레이션 시 `app_theme_colors.dart`에 추가해야 합니다.

| 색상 | 용도 |
|------|------|
| `textMeta` | 메타 텍스트 (날짜, 태그 이름) |
| `textOnSheet` | BottomSheet 위 텍스트 |
| `icon` | 아이콘 기본 색 |
| `iconOnSheet` | BottomSheet 위 아이콘 |
| `sheetBackground` | BottomSheet 배경 |
| `dropdownBg` | 드롭다운 배경 |
| `searchFieldBg` | 검색 필드 배경 |
| `searchFieldText` | 검색 필드 텍스트 |
| `searchFieldHint` | 검색 필드 힌트 |
| `alarmAccent` | 마감일/알람 아이콘 색 |

### 2.3 ConfigUI (custom_test_app에 없음)

habit_app의 `ConfigUI`는 **theme 폴더 외부 개념**입니다. README에 따르면:

> Custom 위젯은 theme 폴더에 의존하지 않으므로, 다른 앱에서 `lib/custom/`만 복사해 사용할 수 있습니다.

**결정**: `ConfigUI`는 theme과 분리된 UI 상수이므로, **`lib/util/config_ui.dart`로 이동**하여 theme 마이그레이션과 별도로 유지합니다.

### 2.4 테마 모드 관리

| 구분 | habit_app | custom_test_app |
|------|-----------|-----------------|
| 방식 | Riverpod `ThemeNotifier` + `AppStorage` | InheritedWidget `ThemeProvider` + setState |
| 영속화 | ✅ AppStorage에 저장 | ❌ 없음 |

**결정**: habit_app은 이미 Riverpod + 영속화를 사용하므로, **ThemeProvider는 도입하지 않고** `ThemeNotifier`를 유지합니다. `theme_provider.dart`의 `context.themeMode`, `context.toggleTheme`, `context.isDarkMode` 확장만 필요하다면, Riverpod과 연동하는 별도 확장을 만들거나, `ThemeNotifier`를 사용하는 쪽으로 통일합니다.

---

## 3. 마이그레이션 단계

### Phase 1: ConfigUI 분리 (theme과 무관)

1. `lib/theme/config_ui.dart` → `lib/util/config_ui.dart`로 이동
2. 모든 `import 'package:syncflow/theme/config_ui.dart'`를 `import 'package:syncflow/util/config_ui.dart'`로 변경

**영향 파일**: 약 20개 (grep 결과 기준)

---

### Phase 2: theme 폴더 정리 및 새 구조 적용

#### 2.1 제거할 파일

- `app_colors.dart`
- `app_color_scheme.dart`
- `common_color_scheme.dart`
- `palette_context.dart`

#### 2.2 추가할 파일

1. **`theme_provider.dart`** (선택)
   - habit_app은 Riverpod 사용 → `ThemeProvider` InheritedWidget은 생략 가능
   - `context.themeMode`, `context.toggleTheme`, `context.isDarkMode`가 필요하면 `theme_context_extension.dart` 같은 확장으로 `ThemeNotifier`/`ref`와 연동

2. **`app_theme_colors.dart`**
   - custom_test_app 버전을 복사
   - habit_app 전용 색상 추가: `textMeta`, `textOnSheet`, `icon`, `iconOnSheet`, `sheetBackground`, `dropdownBg`, `searchFieldBg`, `searchFieldText`, `searchFieldHint`, `alarmAccent`
   - habit_app의 `AppColors.dark`/`AppColors.light` 색상값을 그대로 반영

3. **`README.md`**
   - custom_test_app README를 복사 후 habit_app에 맞게 수정

---

### Phase 3: 코드 마이그레이션 (context.palette → context.appTheme)

| 기존 | 변경 후 |
|------|---------|
| `context.palette` | `context.appTheme` |
| `p.background` | `p.background` (동일) |
| `p.textMeta` | `p.textMeta` (app_theme_colors에 추가) |
| `p.textOnSheet` | `p.textOnSheet` (추가) |
| `p.icon` | `p.icon` (추가) |
| `p.iconOnSheet` | `p.iconOnSheet` (추가) |
| `p.sheetBackground` | `p.sheetBackground` (추가) |
| `p.dropdownBg` | `p.dropdownBg` (추가) |
| `p.searchFieldBg` | `p.searchFieldBg` (추가) |
| `p.searchFieldText` | `p.searchFieldText` (추가) |
| `p.searchFieldHint` | `p.searchFieldHint` (추가) |
| `p.alarmAccent` | `p.alarmAccent` (추가) |

**import 변경**:
- `import 'package:syncflow/theme/app_colors.dart'` → `import 'package:syncflow/theme/app_theme_colors.dart'`

**영향 파일**: 약 25개

---

### Phase 4: main.dart 및 ThemeData

- `MaterialApp`의 `theme`/`darkTheme`에서 `AppThemeColors.lightBackground`, `AppThemeColors.darkBackground` 사용 (README 2.4 참고)
- habit_app 전용 색상이 있다면 `scaffoldBackgroundColor` 등에 반영

---

## 4. 작업 순서 요약

| 순서 | 작업 | 비고 |
|------|------|------|
| 1 | ConfigUI를 `lib/util/config_ui.dart`로 이동 | theme과 분리 |
| 2 | ConfigUI import 경로 일괄 변경 | |
| 3 | `app_theme_colors.dart` 생성 (habit_app 색상 포함) | custom_test_app + 확장 |
| 4 | `theme_provider.dart` 복사 여부 결정 | Riverpod 유지 시 생략 가능 |
| 5 | `README.md` 복사 및 habit_app용 수정 | |
| 6 | 기존 theme 파일 4개 삭제 | app_colors, app_color_scheme, common_color_scheme, palette_context |
| 7 | `context.palette` → `context.appTheme` 일괄 치환 | |
| 8 | import `app_colors` → `app_theme_colors` 일괄 치환 | |
| 9 | main.dart ThemeData 정리 | |
| 10 | 빌드 및 테스트 | |

---

## 5. 위험 요소 및 주의사항

1. **색상값 차이**: custom_test_app 색상과 habit_app 색상이 다름. habit_app의 `AppColors.dark`/`AppColors.light` 값을 `app_theme_colors.dart`에 그대로 반영해야 시각적 일관성이 유지됩니다.

2. **ThemeProvider vs Riverpod**: custom_test_app은 InheritedWidget, habit_app은 Riverpod. `ThemeProvider`를 그대로 쓰면 `onToggleTheme`에서 `ref.read(themeNotifierProvider.notifier).toggleTheme()`를 호출하도록 래핑해야 합니다. **권장**: ThemeProvider는 사용하지 않고, `context.isDarkMode` 등이 필요하면 `ThemeNotifier` + `Consumer`/`ref.watch`로 처리.

3. **ConfigUI 의존성**: ConfigUI를 util로 옮긴 후에도 모든 참조가 `util/config_ui.dart`로 바뀌어야 합니다.

---

## 6. 참고: custom_test_app README 핵심 요약

- **ThemeProvider**: `themeMode`, `onToggleTheme` 제공, `context.themeMode`, `context.toggleTheme`, `context.isDarkMode`
- **AppThemeColors**: `Theme.of(context).brightness` 기반, static 메서드 또는 `context.appTheme`
- **ThemeData 정의**: `AppThemeColors.lightBackground`, `AppThemeColors.darkBackground` 상수 사용
- **앱별 커스터마이징**: `app_theme_colors.dart` 내부 색상값 수정, 새 semantic 색은 static 메서드 + Helper getter 추가
