# Theme 폴더 사용 가이드

앱 전용 색상을 제공합니다. `material.dart`만 의존하며, 커스텀 스키마 없이 단순하게 구성되어 있습니다.

테마 모드(라이트/다크)는 Riverpod `ThemeNotifier`로 관리됩니다. (`lib/vm/theme_notifier.dart`)

---

## 폴더 구조

```
lib/theme/
  app_theme_colors.dart  # Brightness 기반 앱 색상
  README.md              # 사용 문서
```

---

## 1. AppThemeColors

`Theme.of(context).brightness`로 라이트/다크를 판별해 색상을 반환합니다. ThemeExtension 없이 단순 구현입니다.

### 1.1 Import

```dart
import 'package:syncflow/theme/app_theme_colors.dart';
```

### 1.2 사용 방법

**방법 A: static 메서드**

```dart
Container(color: AppThemeColors.background(context))
Text('제목', style: TextStyle(color: AppThemeColors.textPrimary(context)))
```

**방법 B: extension (context.appTheme)**

```dart
final p = context.appTheme;
Container(color: p.background)
Text('제목', style: TextStyle(color: p.textPrimary))
```

### 1.3 제공 색상

| 메서드 | 설명 |
|--------|------|
| `background` | 전체 배경 |
| `cardBackground` | 카드/패널 배경 |
| `sheetBackground` | BottomSheet 배경 |
| `primary` | 주요 포인트 |
| `accent` | 보조 포인트 |
| `textPrimary` | 기본 텍스트 |
| `textSecondary` | 보조 텍스트 |
| `textMeta` | 메타 텍스트 (날짜, 태그) |
| `textOnPrimary` | Primary 배경 위 텍스트 |
| `textOnSheet` | BottomSheet 위 텍스트 |
| `divider` | 구분선 |
| `icon` | 아이콘 기본 색 |
| `iconOnSheet` | BottomSheet 위 아이콘 |
| `chipSelectedBg` | 칩 선택 배경 |
| `chipSelectedText` | 칩 선택 텍스트 |
| `chipUnselectedBg` | 칩 비선택 배경 |
| `chipUnselectedText` | 칩 비선택 텍스트 |
| `dropdownBg` | 드롭다운 배경 |
| `searchFieldBg` | 검색 필드 배경 |
| `searchFieldText` | 검색 필드 텍스트 |
| `searchFieldHint` | 검색 필드 힌트 |
| `alarmAccent` | 마감일/알람 아이콘 색 |

### 1.4 ThemeData 정의용 상수

`MaterialApp`의 `theme`/`darkTheme`에서 사용할 때는 `BuildContext`가 없으므로 상수를 사용합니다.

```dart
MaterialApp(
  theme: ThemeData(
    scaffoldBackgroundColor: AppThemeColors.lightBackground,
  ),
  darkTheme: ThemeData(
    scaffoldBackgroundColor: AppThemeColors.darkBackground,
  ),
  ...
)
```

| 상수 | 설명 |
|------|------|
| `AppThemeColors.lightBackground` | 라이트 배경 |
| `AppThemeColors.darkBackground` | 다크 배경 |

---

## 2. UI 상수 (ConfigUI)

레이아웃, 반경, 패딩, 타이포 등은 `lib/util/config_ui.dart`의 `ConfigUI` 클래스를 사용합니다.

```dart
import 'package:syncflow/util/config_ui.dart';

ConfigUI.screenPaddingH
ConfigUI.cardRadius
ConfigUI.fontSizeTitle
```

---

## 3. 테마 모드 관리

habit_app은 Riverpod `ThemeNotifier`로 테마 모드를 관리하며, `AppStorage`에 영속화합니다.

```dart
// main.dart
final themeMode = ref.watch(themeNotifierProvider);

// 테마 변경
ref.read(themeNotifierProvider.notifier).setThemeMode(ThemeMode.dark);
ref.read(themeNotifierProvider.notifier).toggleTheme();
```
