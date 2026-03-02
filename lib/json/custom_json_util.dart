import 'dart:convert';

// JSON 유틸리티 클래스
// 저장소와 무관한 순수 JSON 변환 유틸리티입니다.
//
// 주요 기능:
// - 안전한 JSON 파싱 (에러 처리)
// - 객체 ↔ JSON 변환
// - JSON 검증
// - JSON 포맷팅
// - JSON 병합/수정
//
// StorageUtil과의 차이점:
// - StorageUtil: 저장소에 저장/불러오기 + JSON 변환 (저장소 연동 필수)
// - JsonUtil: 순수 JSON 변환만 (저장소와 무관)
class CustomJsonUtil {
  // ============================================
  // 기본 JSON 변환
  // ============================================

  // JSON 문자열을 Map 또는 List로 디코딩
  //
  // 사용 예시:
  // ```dart
  // final json = CustomJsonUtil.decode('{"name": "홍길동", "age": 25}');
  // print(json['name']); // 홍길동
  // ```
  static dynamic decode(String jsonString) {
    try {
      return jsonDecode(jsonString);
    } catch (e) {
      return null;
    }
  }

  // Map 또는 List를 JSON 문자열로 인코딩
  //
  // 사용 예시:
  // ```dart
  // final jsonString = CustomJsonUtil.encode({'name': '홍길동', 'age': 25});
  // print(jsonString); // {"name":"홍길동","age":25}
  // ```
  static String? encode(dynamic value) {
    try {
      return jsonEncode(value);
    } catch (e) {
      return null;
    }
  }

  // JSON 문자열이 유효한지 검증
  //
  // 사용 예시:
  // ```dart
  // if (CustomJsonUtil.isValid('{"name": "홍길동"}')) {
  //   print('유효한 JSON입니다');
  // }
  // ```
  static bool isValid(String jsonString) {
    try {
      jsonDecode(jsonString);
      return true;
    } catch (e) {
      return false;
    }
  }

  // ============================================
  // 객체 ↔ JSON 변환
  // ============================================

  // JSON 문자열을 객체로 변환
  //
  // 사용 예시:
  // ```dart
  // final jsonString = '{"name": "홍길동", "age": 25}';
  // final user = CustomJsonUtil.fromJson<User>(
  //   jsonString,
  //   (json) => User.fromJson(json),
  // );
  // ```
  static T? fromJson<T>(
    String jsonString,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return fromJson(json);
    } catch (e) {
      return null;
    }
  }

  // 객체를 JSON 문자열로 변환
  //
  // 사용 예시:
  // ```dart
  // final user = User(name: '홍길동', age: 25);
  // final jsonString = CustomJsonUtil.toJson(user);
  // ```
  static String? toJson(dynamic object) {
    try {
      return jsonEncode(object);
    } catch (e) {
      return null;
    }
  }

  // JSON 문자열 리스트를 객체 리스트로 변환
  //
  // 사용 예시:
  // ```dart
  // final jsonString = '[{"name": "홍길동"}, {"name": "김철수"}]';
  // final users = CustomJsonUtil.fromJsonList<User>(
  //   jsonString,
  //   (json) => User.fromJson(json),
  // );
  // ```
  static List<T>? fromJsonList<T>(
    String jsonString,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    try {
      final jsonList = jsonDecode(jsonString) as List<dynamic>;
      return jsonList
          .map((json) => fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return null;
    }
  }

  // 객체 리스트를 JSON 문자열로 변환
  //
  // 사용 예시:
  // ```dart
  // final users = [User(name: '홍길동'), User(name: '김철수')];
  // final jsonString = CustomJsonUtil.toJsonList(users);
  // ```
  static String? toJsonList(List<dynamic> list) {
    try {
      return jsonEncode(list);
    } catch (e) {
      return null;
    }
  }

  // ============================================
  // JSON 포맷팅
  // ============================================

  // JSON 문자열을 보기 좋게 포맷팅 (들여쓰기)
  //
  // 사용 예시:
  // ```dart
  // final formatted = CustomJsonUtil.format('{"name":"홍길동","age":25}');
  // // {
  // //   "name": "홍길동",
  // //   "age": 25
  // // }
  // ```
  static String? format(String jsonString) {
    try {
      final json = jsonDecode(jsonString);
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(json);
    } catch (e) {
      return null;
    }
  }

  // JSON 문자열을 압축 (공백 제거)
  //
  // 사용 예시:
  // ```dart
  // final compressed = CustomJsonUtil.compress('{"name": "홍길동", "age": 25}');
  // // {"name":"홍길동","age":25}
  // ```
  static String? compress(String jsonString) {
    try {
      final json = jsonDecode(jsonString);
      return jsonEncode(json);
    } catch (e) {
      return null;
    }
  }

  // Map을 포맷팅된 문자열로 변환 (디버깅/표시용)
  //
  // 사용 예시:
  // ```dart
  // final map = {'name': '홍길동', 'age': 25, 'address': {'city': '서울'}};
  // final formatted = CustomJsonUtil.formatMap(map);
  // // name: 홍길동
  // // age: 25
  // // address: {
  // //   city: 서울
  // // }
  // ```
  static String formatMap(Map<String, dynamic> map, {int indent = 0}) {
    final buffer = StringBuffer();
    final indentStr = '  ' * indent;

    for (final entry in map.entries) {
      final key = entry.key;
      final value = entry.value;

      if (value is Map<String, dynamic>) {
        buffer.writeln('$indentStr$key: {');
        buffer.write(formatMap(value, indent: indent + 1));
        buffer.writeln('$indentStr}');
      } else if (value is List) {
        buffer.writeln('$indentStr$key: [');
        for (int i = 0; i < value.length; i++) {
          if (value[i] is Map<String, dynamic>) {
            buffer.writeln('$indentStr  [$i]: {');
            buffer.write(formatMap(
              value[i] as Map<String, dynamic>,
              indent: indent + 2,
            ));
            buffer.writeln('$indentStr  }');
          } else {
            buffer.writeln('$indentStr  [$i]: ${value[i]}');
          }
        }
        buffer.writeln('$indentStr]');
      } else {
        buffer.writeln('$indentStr$key: $value');
      }
    }

    return buffer.toString();
  }

  // ============================================
  // JSON 병합/수정
  // ============================================

  // 두 JSON 객체를 병합
  //
  // 사용 예시:
  // ```dart
  // final json1 = {'name': '홍길동'};
  // final json2 = {'age': 25};
  // final merged = CustomJsonUtil.merge(json1, json2);
  // // {'name': '홍길동', 'age': 25}
  // ```
  static Map<String, dynamic> merge(
    Map<String, dynamic> json1,
    Map<String, dynamic> json2,
  ) {
    return {...json1, ...json2};
  }

  // JSON 객체에서 경로로 값 가져오기
  //
  // 사용 예시:
  // ```dart
  // final json = {'user': {'name': '홍길동', 'age': 25}};
  // final name = CustomJsonUtil.getValue(json, 'user.name');
  // // '홍길동'
  // ```
  static dynamic getValue(Map<String, dynamic> json, String path) {
    try {
      final keys = path.split('.');
      dynamic value = json;

      for (final key in keys) {
        if (value is Map<String, dynamic>) {
          value = value[key];
        } else {
          return null;
        }
      }

      return value;
    } catch (e) {
      return null;
    }
  }

  // JSON 객체에서 경로로 값 설정하기
  //
  // 사용 예시:
  // ```dart
  // final json = {'user': {'name': '홍길동'}};
  // CustomJsonUtil.setValue(json, 'user.age', 25);
  // // {'user': {'name': '홍길동', 'age': 25}}
  // ```
  static bool setValue(Map<String, dynamic> json, String path, dynamic value) {
    try {
      final keys = path.split('.');
      Map<String, dynamic> current = json;

      for (int i = 0; i < keys.length - 1; i++) {
        final key = keys[i];
        if (current[key] == null || current[key] is! Map<String, dynamic>) {
          current[key] = <String, dynamic>{};
        }
        current = current[key] as Map<String, dynamic>;
      }

      current[keys.last] = value;
      return true;
    } catch (e) {
      return false;
    }
  }

  // JSON 객체에서 경로로 값 삭제하기
  //
  // 사용 예시:
  // ```dart
  // final json = {'user': {'name': '홍길동', 'age': 25}};
  // CustomJsonUtil.removeValue(json, 'user.age');
  // // {'user': {'name': '홍길동'}}
  // ```
  static bool removeValue(Map<String, dynamic> json, String path) {
    try {
      final keys = path.split('.');
      Map<String, dynamic> current = json;

      for (int i = 0; i < keys.length - 1; i++) {
        final key = keys[i];
        if (current[key] is! Map<String, dynamic>) {
          return false;
        }
        current = current[key] as Map<String, dynamic>;
      }

      current.remove(keys.last);
      return true;
    } catch (e) {
      return false;
    }
  }

  // JSON 객체에서 키로 검색하기 (재귀적 검색)
  //
  // 사용 예시:
  // ```dart
  // final json = {
  //   'user': {'name': '홍길동', 'age': 25},
  //   'admin': {'name': '관리자', 'role': 'admin'},
  // };
  // final results = CustomJsonUtil.searchKeys(json, 'name');
  // // [MapEntry('user.name', '홍길동'), MapEntry('admin.name', '관리자')]
  //
  // // 대소문자 구분하여 검색
  // final results2 = CustomJsonUtil.searchKeys(json, 'Name', caseSensitive: true);
  //
  // // 정확한 이름만 검색 (부분 일치 제외)
  // final results3 = CustomJsonUtil.searchKeys(json, 'name', exactMatch: true);
  // ```
  static List<MapEntry<String, dynamic>> searchKeys(
    Map<String, dynamic> json,
    String searchKey, {
    bool caseSensitive = false,
    bool exactMatch = false,
  }) {
    final results = <MapEntry<String, dynamic>>[];
    final trimmedKey = searchKey.trim();

    if (trimmedKey.isEmpty) {
      return results;
    }

    // 검색 키 준비 (대소문자 구분 옵션에 따라)
    final searchKeyLower = caseSensitive ? trimmedKey : trimmedKey.toLowerCase();

    // Map을 재귀적으로 순회하며 키 검색
    void searchInMap(dynamic data, String path) {
      if (data is Map<String, dynamic>) {
        for (final entry in data.entries) {
          final currentPath = path.isEmpty ? entry.key : '$path.${entry.key}';

          // 키 매칭 확인
          bool isMatch = false;
          if (exactMatch) {
            // 정확한 이름 매칭
            if (caseSensitive) {
              isMatch = entry.key == trimmedKey;
            } else {
              isMatch = entry.key.toLowerCase() == searchKeyLower;
            }
          } else {
            // 부분 일치
            if (caseSensitive) {
              isMatch = entry.key.contains(trimmedKey);
            } else {
              isMatch = entry.key.toLowerCase().contains(searchKeyLower);
            }
          }

          if (isMatch) {
            results.add(MapEntry(currentPath, entry.value));
          }

          // 값이 Map이나 List인 경우 재귀적으로 검색
          if (entry.value is Map<String, dynamic>) {
            searchInMap(entry.value, currentPath);
          } else if (entry.value is List) {
            for (int i = 0; i < (entry.value as List).length; i++) {
              searchInMap(
                (entry.value as List)[i],
                '$currentPath[$i]',
              );
            }
          }
        }
      } else if (data is List) {
        for (int i = 0; i < data.length; i++) {
          searchInMap(data[i], '$path[$i]');
        }
      }
    }

    searchInMap(json, '');
    return results;
  }

  // ============================================
  // JSON 검증 및 변환
  // ============================================

  // JSON 문자열을 안전하게 Map으로 변환
  //
  // 사용 예시:
  // ```dart
  // final map = CustomJsonUtil.toMap('{"name": "홍길동"}');
  // ```
  static Map<String, dynamic>? toMap(String jsonString) {
    try {
      final json = jsonDecode(jsonString);
      if (json is Map<String, dynamic>) {
        return json;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // JSON 문자열을 안전하게 List로 변환
  //
  // 사용 예시:
  // ```dart
  // final list = CustomJsonUtil.toList('[1, 2, 3]');
  // ```
  static List<dynamic>? toList(String jsonString) {
    try {
      final json = jsonDecode(jsonString);
      if (json is List<dynamic>) {
        return json;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Map을 JSON 문자열로 변환 (안전)
  //
  // 사용 예시:
  // ```dart
  // final jsonString = CustomJsonUtil.fromMap({'name': '홍길동'});
  // ```
  static String? fromMap(Map<String, dynamic> map) {
    return encode(map);
  }

  // List를 JSON 문자열로 변환 (안전)
  //
  // 사용 예시:
  // ```dart
  // final jsonString = CustomJsonUtil.fromList([1, 2, 3]);
  // ```
  static String? fromList(List<dynamic> list) {
    return encode(list);
  }
}
