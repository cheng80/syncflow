# CustomJsonUtil

저장소와 무관한 순수 JSON 변환 유틸리티 클래스입니다.

## StorageUtil과의 차이점

- **StorageUtil**: 저장소(SharedPreferences)에 저장/불러오기 + JSON 변환 (저장소 연동 필수)
- **JsonUtil**: 순수 JSON 변환만 (저장소와 무관)

## 주요 기능

### 1. 기본 JSON 변환

```dart
// JSON 디코딩
final json = CustomJsonUtil.decode('{"name": "홍길동", "age": 25}');
print(json['name']); // 홍길동

// JSON 인코딩
final jsonString = CustomJsonUtil.encode({'name': '홍길동', 'age': 25});
print(jsonString); // {"name":"홍길동","age":25}
```

### 2. JSON 검증

```dart
if (CustomJsonUtil.isValid('{"name": "홍길동"}')) {
  print('유효한 JSON입니다');
}
```

### 3. 객체 ↔ JSON 변환

```dart
// JSON → 객체
final jsonString = '{"name": "홍길동", "age": 25}';
final user = CustomJsonUtil.fromJson<User>(
  jsonString,
  (json) => User.fromJson(json),
);

// 객체 → JSON
final jsonString = CustomJsonUtil.toJson(user);
```

### 4. JSON 포맷팅

```dart
// 포맷팅 (들여쓰기)
final formatted = CustomJsonUtil.format('{"name":"홍길동","age":25}');
// {
//   "name": "홍길동",
//   "age": 25
// }

// 압축 (공백 제거)
final compressed = CustomJsonUtil.compress(formatted);

// Map을 포맷팅된 문자열로 변환 (디버깅/표시용)
final map = {'name': '홍길동', 'age': 25, 'address': {'city': '서울'}};
final formattedMap = CustomJsonUtil.formatMap(map);
// name: 홍길동
// age: 25
// address: {
//   city: 서울
// }
```

### 5. JSON 병합/수정

```dart
// 병합
final json1 = {'name': '홍길동'};
final json2 = {'age': 25};
final merged = CustomJsonUtil.merge(json1, json2);
// {'name': '홍길동', 'age': 25}

// 경로로 값 가져오기
final name = CustomJsonUtil.getValue(json, 'user.name');

// 경로로 값 설정하기
CustomJsonUtil.setValue(json, 'user.email', 'hong@example.com');

// 경로로 값 삭제하기
CustomJsonUtil.removeValue(json, 'user.age');

// 키로 검색하기 (재귀적 검색)
final json = {
  'user': {'name': '홍길동', 'age': 25, 'userName': 'hong123'},
  'admin': {'name': '관리자', 'role': 'admin'},
};
final results = CustomJsonUtil.searchKeys(json, 'name');
// [MapEntry('user.name', '홍길동'), MapEntry('user.userName', 'hong123'), MapEntry('admin.name', '관리자')]

// 대소문자 구분하여 검색
final results2 = CustomJsonUtil.searchKeys(json, 'Name', caseSensitive: true);
// 대소문자를 구분하므로 "Name"과 정확히 일치하는 키만 찾음

// 정확한 이름만 검색 (부분 일치 제외)
final results3 = CustomJsonUtil.searchKeys(json, 'name', exactMatch: true);
// [MapEntry('user.name', '홍길동'), MapEntry('admin.name', '관리자')]
// "userName"은 제외됨 (정확히 "name"인 키만 찾음)
```

## 사용 사례

### API 응답 파싱

```dart
// HTTP 응답 파싱
final response = await http.get(url);
final user = CustomJsonUtil.fromJson<User>(
  response.body,
  (json) => User.fromJson(json),
);
```

### 네트워크 통신

```dart
// 요청 데이터 JSON 변환
final requestData = {'name': '홍길동', 'age': 25};
final jsonBody = CustomJsonUtil.encode(requestData);

// 응답 데이터 파싱
final responseJson = CustomJsonUtil.decode(response.body);
```

## 메서드 목록

### 기본 변환

- `decode(String jsonString)` - JSON 문자열 → Map/List
- `encode(dynamic value)` - Map/List → JSON 문자열
- `isValid(String jsonString)` - JSON 유효성 검증

### 객체 변환

- `fromJson<T>(String jsonString, T Function(Map) fromJson)` - JSON → 객체
- `toJson(dynamic object)` - 객체 → JSON
- `fromJsonList<T>(String jsonString, T Function(Map) fromJson)` - JSON → 객체 리스트
- `toJsonList(List<dynamic> list)` - 객체 리스트 → JSON

### 포맷팅

- `format(String jsonString)` - JSON 포맷팅 (들여쓰기)
- `compress(String jsonString)` - JSON 압축 (공백 제거)
- `formatMap(Map map, {int indent})` - Map을 포맷팅된 문자열로 변환 (디버깅/표시용)

### 병합/수정

- `merge(Map json1, Map json2)` - JSON 병합
- `getValue(Map json, String path)` - 경로로 값 가져오기
- `setValue(Map json, String path, dynamic value)` - 경로로 값 설정
- `removeValue(Map json, String path)` - 경로로 값 삭제
- `searchKeys(Map json, String searchKey, {bool caseSensitive, bool exactMatch})` - 키로 검색 (재귀적 검색)
  - `caseSensitive`: true면 대소문자 구분 (기본값: false)
  - `exactMatch`: true면 정확한 이름만 검색, false면 부분 일치 (기본값: false)

### 안전 변환

- `toMap(String jsonString)` - JSON → Map (안전)
- `toList(String jsonString)` - JSON → List (안전)
- `fromMap(Map map)` - Map → JSON (안전)
- `fromList(List list)` - List → JSON (안전)

## 의존성

- `dart:convert` (기본 제공)

## 참고

- StorageUtil과 함께 사용하면 저장소 연동과 JSON 변환을 모두 처리할 수 있습니다.
- 네트워크 통신 클래스와 함께 사용하면 API 요청/응답 처리가 용이합니다.
