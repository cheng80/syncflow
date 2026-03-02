# CustomNavigationUtil

GetX의 `Get.to`, `Get.toNamed` 등과 유사한 기능을 제공하는 네비게이션 유틸리티입니다.

Flutter의 기본 `Navigator`를 래핑하여 더 간편하게 사용할 수 있습니다.

## 주요 기능

### 기본 네비게이션

- `to()` - 새 페이지로 이동 (Get.to와 유사)
- `toNamed()` - 라우트 이름으로 이동 (Get.toNamed와 유사)
- `off()` - 현재 페이지를 대체하고 이동 (Get.off와 유사)
- `offNamed()` - 현재 페이지를 대체하고 라우트로 이동 (Get.offNamed와 유사)
- `offAll()` - 모든 페이지를 제거하고 이동 (Get.offAll와 유사)
- `offAllNamed()` - 모든 페이지를 제거하고 라우트로 이동 (Get.offAllNamed와 유사)

### 뒤로 가기

- `back()` - 이전 페이지로 돌아가기 (Get.back와 유사)
- `until()` - 특정 조건까지 뒤로 가기 (Get.until와 유사)
- `untilNamed()` - 특정 라우트까지 뒤로 가기
- `untilFirst()` - 첫 번째 페이지까지 뒤로 가기

### 유틸리티

- `currentRoute()` - 현재 라우트 이름 가져오기
- `arguments()` - 현재 라우트의 arguments 가져오기
- `canPop()` - 뒤로 갈 수 있는지 확인
- `stackCount()` - 스택에 있는 페이지 수 확인

## 사용 예시

### 기본 사용

```dart
import 'package:flutter/material.dart';
import 'package:custom_test_app/custom/utils_core.dart';

// 새 페이지로 이동
CustomNavigationUtil.to(
  context,
  const NextPage(),
);

// 라우트 이름으로 이동
CustomNavigationUtil.toNamed(
  context,
  '/detail',
  arguments: {'id': 123},
);

// 이전 페이지로 돌아가기
CustomNavigationUtil.back(context);

// 반환값과 함께 돌아가기
CustomNavigationUtil.back(context, result: '반환값');
```

### Future 반환값 활용

모든 네비게이션 메서드는 `Future<T?>`를 반환하므로 `.then()`, `.catchError()`, `await` 등을 사용할 수 있습니다.

```dart
// .then() 사용
CustomNavigationUtil.to(context, const NextPage())
  .then((result) {
    print('반환값: $result');
  })
  .catchError((error) {
    print('에러: $error');
  });

// await 사용
final result = await CustomNavigationUtil.to(
  context,
  const NextPage(),
);
print('반환값: $result');

// 라우트로 이동 후 반환값 처리
CustomNavigationUtil.toNamed(context, '/detail')
  .then((result) {
    if (result != null) {
      print('상세 페이지에서 반환: $result');
    }
  });
```

### 현재 페이지 대체

```dart
// 현재 페이지를 대체하고 이동
CustomNavigationUtil.off(
  context,
  const LoginPage(),
);

// 라우트로 대체
CustomNavigationUtil.offNamed(
  context,
  '/login',
);
```

### 모든 페이지 제거 후 이동

```dart
// 모든 페이지를 제거하고 이동
CustomNavigationUtil.offAll(
  context,
  const HomePage(),
);

// 라우트로 이동
CustomNavigationUtil.offAllNamed(
  context,
  '/home',
);
```

### 특정 페이지까지 뒤로 가기

```dart
// 홈 페이지까지 뒤로 가기
CustomNavigationUtil.untilNamed(context, '/home');

// 첫 번째 페이지까지 뒤로 가기
CustomNavigationUtil.untilFirst(context);

// 조건에 맞는 페이지까지 뒤로 가기
CustomNavigationUtil.until(
  context,
  (route) => route.settings.name == '/home',
);
```

### 현재 라우트 정보 가져오기

```dart
// 현재 라우트 이름
final route = CustomNavigationUtil.currentRoute(context);
print('현재 라우트: $route');

// arguments 가져오기
final args = CustomNavigationUtil.arguments<Map<String, dynamic>>(context);
final id = args?['id'];

// 뒤로 갈 수 있는지 확인
if (CustomNavigationUtil.canPop(context)) {
  CustomNavigationUtil.back(context);
}
```

## GetX와의 비교

| GetX | CustomNavigationUtil | 설명 |
|------|---------------------|------|
| `Get.to(Widget)` | `CustomNavigationUtil.to(context, Widget)` | 새 페이지로 이동 |
| `Get.toNamed(String)` | `CustomNavigationUtil.toNamed(context, String)` | 라우트로 이동 |
| `Get.off(Widget)` | `CustomNavigationUtil.off(context, Widget)` | 현재 페이지 대체 |
| `Get.offNamed(String)` | `CustomNavigationUtil.offNamed(context, String)` | 라우트로 대체 |
| `Get.offAll(Widget)` | `CustomNavigationUtil.offAll(context, Widget)` | 모든 페이지 제거 후 이동 |
| `Get.offAllNamed(String)` | `CustomNavigationUtil.offAllNamed(context, String)` | 모든 페이지 제거 후 라우트로 이동 |
| `Get.back()` | `CustomNavigationUtil.back(context)` | 이전 페이지로 돌아가기 |
| `Get.until(predicate)` | `CustomNavigationUtil.until(context, predicate)` | 조건까지 뒤로 가기 |

## 주의사항

- 모든 메서드는 `BuildContext`를 필요로 합니다.
- `MaterialApp`의 `routes`에 라우트가 등록되어 있어야 `toNamed` 등을 사용할 수 있습니다.
- `arguments`는 타입 안전성을 위해 제네릭을 사용하여 캐스팅할 수 있습니다.

