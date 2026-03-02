import 'package:flutter/material.dart';
import 'custom_json_util.dart';

// 예제용 User 클래스
class User {
  final String name;
  final int age;
  final String email;

  User({
    required this.name,
    required this.age,
    required this.email,
  });

  // JSON Map에서 User 객체 생성
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      name: json['name'] as String,
      age: json['age'] as int,
      email: json['email'] as String,
    );
  }

  // User 객체를 JSON Map으로 변환
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'age': age,
      'email': email,
    };
  }

  @override
  String toString() {
    return 'User(name: $name, age: $age, email: $email)';
  }
}

// JsonUtil 사용 예제 페이지
class JsonUtilExamplePage extends StatefulWidget {
  const JsonUtilExamplePage({super.key});

  @override
  State<JsonUtilExamplePage> createState() => _JsonUtilExamplePageState();
}

class _JsonUtilExamplePageState extends State<JsonUtilExamplePage> {
  String _result = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('JsonUtil 예제')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: _basicExample,
              child: const Text('기본 JSON 변환'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _objectExample,
              child: const Text('객체 ↔ JSON 변환'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _validationExample,
              child: const Text('JSON 검증'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _formattingExample,
              child: const Text('JSON 포맷팅'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _mergeExample,
              child: const Text('JSON 병합'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _pathExample,
              child: const Text('경로로 값 가져오기/설정'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _searchKeysExample,
              child: const Text('키로 검색하기'),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _result.isEmpty ? '위 버튼을 눌러 예제를 실행하세요' : _result,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 기본 JSON 변환 예제
  void _basicExample() {
    setState(() {
      _result = '═══════════════════════════════════════\n';
      _result += '📋 기본 JSON 변환 예제\n';
      _result += '═══════════════════════════════════════\n\n';

      _result += '【1단계】JSON 문자열 → Map 변환 (디코딩)\n';
      _result += '─────────────────────────────────────\n';
      final jsonString = '{"name": "홍길동", "age": 25}';
      _result += '📥 입력 (JSON 문자열):\n';
      _result += '   $jsonString\n\n';

      final decoded = CustomJsonUtil.decode(jsonString);
      _result += '📤 출력 (Map 객체):\n';
      _result += '   $decoded\n\n';

      _result += '📊 Map에서 값 접근:\n';
      _result += '   name: ${decoded?['name']}\n';
      _result += '   age: ${decoded?['age']}\n\n';

      _result += '【2단계】Map → JSON 문자열 변환 (인코딩)\n';
      _result += '─────────────────────────────────────\n';
      final map = {'name': '김철수', 'age': 30};
      _result += '📥 입력 (Map 객체):\n';
      _result += '   $map\n\n';

      final encoded = CustomJsonUtil.encode(map);
      _result += '📤 출력 (JSON 문자열):\n';
      _result += '   $encoded\n';
    });
  }

  // 객체 ↔ JSON 변환 예제
  void _objectExample() {
    setState(() {
      _result = '═══════════════════════════════════════\n';
      _result += '🔄 객체 ↔ JSON 변환 예제\n';
      _result += '═══════════════════════════════════════\n\n';

      _result += '【1단계】User 객체 생성\n';
      _result += '─────────────────────────────────────\n';
      final user = User(
        name: '홍길동',
        age: 25,
        email: 'hong@example.com',
      );
      _result += '📦 User 객체:\n';
      _result += '   $user\n\n';

      _result += '【2단계】User 객체 → JSON 문자열 변환\n';
      _result += '─────────────────────────────────────\n';
      _result += '📥 입력: User 객체\n';
      _result += '   $user\n\n';

      // User 객체를 Map으로 변환 후 JSON 문자열로 변환
      final userMap = user.toJson();
      final jsonString = CustomJsonUtil.encode(userMap);
      _result += '📤 출력 (JSON 문자열):\n';
      _result += '   $jsonString\n\n';

      _result += '【3단계】JSON 문자열 → User 객체 변환\n';
      _result += '─────────────────────────────────────\n';
      _result += '📥 입력 (JSON 문자열):\n';
      _result += '   $jsonString\n\n';

      if (jsonString != null) {
        // CustomJsonUtil.fromJson을 사용하여 User 객체로 변환
        final convertedUser = CustomJsonUtil.fromJson<User>(
          jsonString,
          (json) => User.fromJson(json),
        );
        _result += '📤 출력 (User 객체):\n';
        _result += '   $convertedUser\n\n';

        _result += '✅ 변환 성공! 객체의 속성 접근:\n';
        _result += '   이름: ${convertedUser?.name}\n';
        _result += '   나이: ${convertedUser?.age}\n';
        _result += '   이메일: ${convertedUser?.email}\n\n';
      }

      _result += '【4단계】User 리스트 ↔ JSON 변환\n';
      _result += '─────────────────────────────────────\n';
      final users = [
        User(name: '홍길동', age: 25, email: 'hong@example.com'),
        User(name: '김철수', age: 30, email: 'kim@example.com'),
      ];
      _result += '📥 입력 (User 리스트):\n';
      _result += '   ${users.map((u) => u.toString()).join(", ")}\n\n';

      // 리스트를 JSON으로 변환
      final usersJsonString = CustomJsonUtil.toJsonList(
        users.map((u) => u.toJson()).toList(),
      );
      _result += '📤 출력 (JSON 문자열):\n';
      _result += '   $usersJsonString\n\n';

      // JSON 문자열을 다시 User 리스트로 변환
      if (usersJsonString != null) {
        final convertedUsers = CustomJsonUtil.fromJsonList<User>(
          usersJsonString,
          (json) => User.fromJson(json),
        );
        _result += '🔄 JSON → User 리스트 변환:\n';
        _result += '   ${convertedUsers?.map((u) => u.toString()).join(", ")}\n';
      }
    });
  }

  // JSON 검증 예제
  void _validationExample() {
    setState(() {
      _result = '═══════════════════════════════════════\n';
      _result += '✅ JSON 검증 예제\n';
      _result += '═══════════════════════════════════════\n\n';

      _result += '【케이스 1】유효한 JSON 문자열 검증\n';
      _result += '─────────────────────────────────────\n';
      final validJson = '{"name": "홍길동"}';
      _result += '📥 입력:\n';
      _result += '   $validJson\n';
      _result += '📊 검증 결과: ${CustomJsonUtil.isValid(validJson) ? "✅ 유효함" : "❌ 유효하지 않음"}\n\n';

      _result += '【케이스 2】유효하지 않은 JSON 문자열 검증\n';
      _result += '─────────────────────────────────────\n';
      final invalidJson = '{name: 홍길동}'; // 따옴표 없음
      _result += '📥 입력:\n';
      _result += '   $invalidJson\n';
      _result += '⚠️  문제점: 키(name)에 따옴표가 없어서 유효하지 않음\n';
      _result += '📊 검증 결과: ${CustomJsonUtil.isValid(invalidJson) ? "✅ 유효함" : "❌ 유효하지 않음"}\n';
    });
  }

  // JSON 포맷팅 예제
  void _formattingExample() {
    setState(() {
      _result = '═══════════════════════════════════════\n';
      _result += '🎨 JSON 포맷팅 예제\n';
      _result += '═══════════════════════════════════════\n\n';

      _result += '【1단계】원본 JSON (압축된 형태)\n';
      _result += '─────────────────────────────────────\n';
      final jsonString = '{"name":"홍길동","age":25,"email":"hong@example.com"}';
      _result += '📥 입력:\n';
      _result += '   $jsonString\n\n';

      _result += '【2단계】포맷팅 (들여쓰기 적용)\n';
      _result += '─────────────────────────────────────\n';
      final formatted = CustomJsonUtil.format(jsonString);
      _result += '📤 출력 (읽기 쉬운 형태):\n';
      _result += '$formatted\n\n';

      _result += '【3단계】다시 압축 (공백 제거)\n';
      _result += '─────────────────────────────────────\n';
      final compressed = CustomJsonUtil.compress(formatted ?? '');
      _result += '📤 출력 (압축된 형태):\n';
      _result += '   $compressed\n';
    });
  }

  // JSON 병합 예제
  void _mergeExample() {
    setState(() {
      _result = '═══════════════════════════════════════\n';
      _result += '🔀 JSON 병합 예제\n';
      _result += '═══════════════════════════════════════\n\n';

      _result += '【1단계】두 개의 Map 객체 준비\n';
      _result += '─────────────────────────────────────\n';
      final json1 = {'name': '홍길동', 'age': 25};
      final json2 = {'email': 'hong@example.com', 'city': '서울'};
      _result += '📦 Map 1:\n';
      _result += '   $json1\n';
      _result += '📦 Map 2:\n';
      _result += '   $json2\n\n';

      _result += '【2단계】두 Map 병합\n';
      _result += '─────────────────────────────────────\n';
      final merged = CustomJsonUtil.merge(json1, json2);
      _result += '📤 병합 결과:\n';
      _result += '   $merged\n\n';
      _result += '💡 설명: Map2의 키가 Map1의 키와 겹치면 Map2의 값으로 덮어씁니다.\n';
    });
  }

  // 경로로 값 가져오기/설정 예제
  void _pathExample() {
    setState(() {
      _result = '═══════════════════════════════════════\n';
      _result += '🗺️  경로로 값 가져오기/설정 예제\n';
      _result += '═══════════════════════════════════════\n\n';

      _result += '📖 기능 설명:\n';
      _result += '─────────────────────────────────────\n';
      _result += '중첩된 Map 구조에서 점(.)으로 구분된 경로 문자열을 사용하여\n';
      _result += '깊이 있는 위치의 값을 읽거나 쓰는 기능입니다.\n\n';
      _result += '💡 왜 필요한가?\n';
      _result += '일반적인 방법: json[\'user\']?[\'name\'] (번거로움)\n';
      _result += '경로 방식: getValue(json, \'user.name\') (간편함)\n\n';
      _result += '🔍 사용 사례:\n';
      _result += '• API 응답에서 중첩된 JSON의 특정 값만 추출\n';
      _result += '• 설정 파일의 특정 항목만 읽기/쓰기\n';
      _result += '• 깊은 경로의 값만 수정\n\n';

      _result += '【1단계】중첩된 Map 구조 준비\n';
      _result += '─────────────────────────────────────\n';
      _result += '이 예제에서는 user 객체 안에 address 객체가 중첩된 구조를 사용합니다.\n';
      _result += '경로 예시:\n';
      _result += '  • "user.name" → "홍길동"\n';
      _result += '  • "user.address.city" → "서울"\n\n';
      final json = {
        'user': {
          'name': '홍길동',
          'age': 25,
          'address': {'city': '서울', 'street': '강남구'},
        },
      };
      _result += '📦 원본 Map 구조:\n';
      _result += '${CustomJsonUtil.format(CustomJsonUtil.encode(json) ?? '')}\n\n';

      _result += '【2단계】경로로 값 가져오기 (getValue)\n';
      _result += '─────────────────────────────────────\n';
      _result += '점(.)으로 구분된 경로를 사용하여 중첩된 값을 한 번에 가져옵니다.\n\n';
      final name = CustomJsonUtil.getValue(json, 'user.name');
      final city = CustomJsonUtil.getValue(json, 'user.address.city');
      _result += '📥 경로: "user.name"\n';
      _result += '   설명: user 객체의 name 필드에 접근\n';
      _result += '📤 값: $name\n\n';
      _result += '📥 경로: "user.address.city"\n';
      _result += '   설명: user 객체 안의 address 객체의 city 필드에 접근\n';
      _result += '📤 값: $city\n\n';

      _result += '【3단계】경로로 값 설정하기 (setValue)\n';
      _result += '─────────────────────────────────────\n';
      _result += '경로를 사용하여 중첩된 구조의 특정 위치에 값을 설정합니다.\n';
      _result += '경로가 존재하지 않으면 자동으로 생성됩니다.\n\n';
      CustomJsonUtil.setValue(json, 'user.email', 'hong@example.com');
      CustomJsonUtil.setValue(json, 'user.address.zipcode', '12345');
      _result += '➕ 설정: user.email = "hong@example.com"\n';
      _result += '   결과: user 객체에 email 필드가 추가됨\n\n';
      _result += '➕ 설정: user.address.zipcode = "12345"\n';
      _result += '   결과: address 객체에 zipcode 필드가 추가됨\n\n';
      _result += '📦 값 설정 후 Map 구조:\n';
      _result += '${CustomJsonUtil.format(CustomJsonUtil.encode(json) ?? '')}\n\n';

      _result += '【4단계】경로로 값 삭제하기 (removeValue)\n';
      _result += '─────────────────────────────────────\n';
      _result += '경로를 사용하여 중첩된 구조의 특정 위치에 있는 값을 삭제합니다.\n\n';
      CustomJsonUtil.removeValue(json, 'user.age');
      _result += '➖ 삭제: user.age\n';
      _result += '   결과: user 객체에서 age 필드가 제거됨\n\n';
      _result += '📦 값 삭제 후 Map 구조:\n';
      _result += '${CustomJsonUtil.format(CustomJsonUtil.encode(json) ?? '')}\n';
    });
  }

  // 키로 검색하기 예제
  void _searchKeysExample() {
    setState(() {
      _result = '═══════════════════════════════════════\n';
      _result += '🔍 키로 검색하기 예제\n';
      _result += '═══════════════════════════════════════\n\n';

      _result += '📖 기능 설명:\n';
      _result += '─────────────────────────────────────\n';
      _result += 'Map 구조를 재귀적으로 순회하여 특정 키 이름을 포함하는\n';
      _result += '모든 항목을 찾아 경로와 값을 함께 반환합니다.\n\n';
      _result += '💡 기본 특징:\n';
      _result += '• 기본적으로 대소문자 구분 없이 검색 (옵션으로 변경 가능)\n';
      _result += '• 기본적으로 부분 일치 지원 (옵션으로 정확한 매칭 가능)\n';
      _result += '• 중첩된 Map과 List 모두 검색\n';
      _result += '• 경로 정보와 함께 반환\n\n';
      _result += '⚙️ 옵션:\n';
      _result += '• caseSensitive: true → 대소문자 구분하여 검색\n';
      _result += '• exactMatch: true → 정확한 이름만 검색 (부분 일치 제외)\n\n';

      _result += '【1단계】검색 대상 Map 구조 준비\n';
      _result += '─────────────────────────────────────\n';
      final json = {
        'user': {
          'name': '홍길동',
          'age': 25,
          'userName': 'hong123',
          'address': {'city': '서울', 'street': '강남구'},
        },
        'admin': {
          'name': '관리자',
          'role': 'admin',
          'adminName': 'admin001',
        },
        'items': [
          {'itemName': '상품1', 'price': 1000},
          {'itemName': '상품2', 'price': 2000},
        ],
      };
      _result += '📦 검색 대상 Map 구조:\n';
      _result += '${CustomJsonUtil.formatMap(json)}\n\n';

      _result += '【2단계】"name" 키로 검색\n';
      _result += '─────────────────────────────────────\n';
      final nameResults = CustomJsonUtil.searchKeys(json, 'name');
      _result += '📥 검색 키: "name"\n';
      _result += '📊 검색 결과: ${nameResults.length}개\n\n';
      for (int i = 0; i < nameResults.length; i++) {
        final entry = nameResults[i];
        _result += '  [$i] 경로: "${entry.key}"\n';
        _result += '      값: ${entry.value}\n';
      }
      _result += '\n';

      _result += '【3단계】대소문자 구분하여 검색\n';
      _result += '─────────────────────────────────────\n';
      final nameResults2 = CustomJsonUtil.searchKeys(json, 'Name', caseSensitive: true);
      _result += '📥 검색 키: "Name" (대소문자 구분)\n';
      _result += '⚙️ 옵션: caseSensitive: true\n';
      _result += '📊 검색 결과: ${nameResults2.length}개\n';
      if (nameResults2.isNotEmpty) {
        for (int i = 0; i < nameResults2.length; i++) {
          final entry = nameResults2[i];
          _result += '  [$i] 경로: "${entry.key}"\n';
          _result += '      값: ${entry.value}\n';
        }
      } else {
        _result += '💡 설명: 대소문자를 구분하므로 "Name"과 정확히 일치하는 키만 찾음\n';
      }
      _result += '\n';

      _result += '【4단계】정확한 이름만 검색 (부분 일치 제외)\n';
      _result += '─────────────────────────────────────\n';
      final exactResults = CustomJsonUtil.searchKeys(json, 'name', exactMatch: true);
      _result += '📥 검색 키: "name"\n';
      _result += '⚙️ 옵션: exactMatch: true\n';
      _result += '📊 검색 결과: ${exactResults.length}개\n';
      _result += '💡 설명: 정확히 "name"인 키만 찾음 ("userName", "adminName" 제외)\n\n';
      for (int i = 0; i < exactResults.length; i++) {
        final entry = exactResults[i];
        _result += '  [$i] 경로: "${entry.key}"\n';
        _result += '      값: ${entry.value}\n';
      }
      _result += '\n';

      _result += '【5단계】"user" 키로 검색 (부분 일치 - 기본 동작)\n';
      _result += '─────────────────────────────────────\n';
      final userResults = CustomJsonUtil.searchKeys(json, 'user');
      _result += '📥 검색 키: "user"\n';
      _result += '⚙️ 옵션: 기본값 (caseSensitive: false, exactMatch: false)\n';
      _result += '📊 검색 결과: ${userResults.length}개\n';
      _result += '💡 설명: "user", "userName" 등 "user"를 포함하는 모든 키 찾음\n\n';
      for (int i = 0; i < userResults.length; i++) {
        final entry = userResults[i];
        _result += '  [$i] 경로: "${entry.key}"\n';
        if (entry.value is Map) {
          _result += '      값: {Map with ${(entry.value as Map).length} keys}\n';
        } else {
          _result += '      값: ${entry.value}\n';
        }
      }
      _result += '\n';

      _result += '【6단계】존재하지 않는 키로 검색\n';
      _result += '─────────────────────────────────────\n';
      final notFoundResults = CustomJsonUtil.searchKeys(json, 'notfound');
      _result += '📥 검색 키: "notfound"\n';
      _result += '📊 검색 결과: ${notFoundResults.length}개\n';
      _result += '💡 설명: 검색 결과가 없으면 빈 리스트 반환\n';
    });
  }
}
