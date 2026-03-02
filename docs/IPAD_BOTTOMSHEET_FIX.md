# iPad 바텀시트 즉시 닫힘 버그 수정 가이드

> 다른 앱에서 동일 증상 발생 시 **이 문서를 참고하여 수정**하세요.

---

## 증상

- **iPad**에서 상단 버튼(AppBar 등) 탭 시 바텀시트가 뜨자마자 바로 닫힘
- 리스트 아이템 탭/롱프레스에서 여는 시트는 정상 동작
- iPhone에서는 문제 없음

---

## 원인

### A. iPadOS 26.1 Flutter 버그 (주요 원인)

- **상태바(status bar) 탭이 가짜 터치 이벤트로 전달**되어 모달이 즉시 닫힘
- AppBar 상단 버튼 탭 시 상태바 영역과 겹쳐 이 현상 발생
- **리스트 아이템 탭/롱프레스 등 화면 중간·하단에서는 발생하지 않음**
- Flutter 3.41.0에서 수정 → 이후 크래시로 revert → 재수정 대기 중 (2026-02 기준)
- [Flutter Issue #177992](https://github.com/flutter/flutter/issues/177992)

### B. Drawer → 시트 오픈 시 레이스 (부가 원인)

- Drawer를 닫는 `Navigator.pop`과 시트 오픈이 겹쳐 시트가 즉시 닫힘
- iPad에서 화면 계층이 복잡할 때 발생

---

## 수정 방법

### 1. `isDismissible: false` — 상단 AppBar 버튼에서 여는 시트만 적용

상태바 가짜 터치는 **상단(AppBar/상태바 근처) 탭에서만 발생**하므로,
AppBar 버튼으로 여는 시트에만 `isDismissible: false`를 적용합니다.

```dart
// AppBar 상단 버튼에서 시트를 여는 경우 → isDismissible: false
final rootContext = Navigator.of(context, rootNavigator: true).context;
showModalBottomSheet<HabitEditResult>(
  context: rootContext,
  useRootNavigator: true,
  isDismissible: false,   // iPadOS 가짜 터치로 barrier 탭 방지
  isScrollControlled: true,
  // ...
);
```

리스트 아이템 탭/롱프레스 등 **화면 중간·하단에서 여는 시트에는 불필요**합니다.

### 2. 루트 Navigator로 열기 — 모든 시트에 적용

iPad에서 Scaffold/Drawer/Showcase 등 복잡한 화면 계층에서는 루트 Navigator를 사용하는 것이 안정적입니다.

```dart
final rootContext = Navigator.of(context, rootNavigator: true).context;
final result = await showModalBottomSheet<Todo>(
  context: rootContext,
  useRootNavigator: true,
  // ...
);
```

### 3. Drawer에서 시트를 여는 경우

Drawer 닫힘 애니메이션과 겹치지 않도록 **짧은 지연** 후 시트 오픈.

```dart
onTap: () async {
  Navigator.pop(context);  // Drawer 닫기
  await Future.delayed(const Duration(milliseconds: 220));
  if (!mounted) return;
  final ctx = rootNavigatorKey.currentContext ?? context;
  if (ctx.mounted) showLanguagePickerSheet(ctx);
},
```

---

## 수정 대상 파일 (HabitCell)

| 파일 | 함수/위치 | 트리거 | 적용 내용 |
|---|---|---|---|
| `lib/view/main_scaffold.dart` | `_openHabitAddSheet` | **AppBar 상단 + 버튼** | rootContext + `isDismissible: false` |
| `lib/view/habit_home.dart` | `_showEditSheet` | 아이템 탭 (중간) | rootContext |
| `lib/view/habit_home.dart` | `_showDeleteSheet` | 아이템 롱프레스 (중간) | rootContext |
| `lib/view/app_drawer.dart` | 언어/잔디 테마 메뉴 | Drawer 메뉴 | Drawer 딜레이 220ms + rootContext |
| `lib/view/widgets/language_picker_sheet.dart` | `showLanguagePickerSheet` | Drawer 경유 | rootContext |
| `lib/view/widgets/heatmap_theme_picker_sheet.dart` | `showHeatmapThemePickerSheet` | Drawer 경유 | rootContext |
| `lib/view/category_settings.dart` | `_showCategoryEditor` | 리스트 아이템 (중간) | rootContext |

---

## 관련 이슈

- [Flutter Issue #177992](https://github.com/flutter/flutter/issues/177992) — iPadOS 상태바 가짜 터치
- Flutter 공식 수정 후에도 AppBar 트리거 시트의 `isDismissible: false`는 안전한 방어 코드로 유지 권장

---

## AI 지시용 프롬프트

```
@docs/IPAD_BOTTOMSHEET_FIX.md 이 문서를 참고하여
iPad에서 바텀시트가 즉시 닫히는 버그를 수정해줘.
showModalBottomSheet를 호출하는 모든 곳을 확인하고 적용해.
```
