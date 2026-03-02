import 'package:flutter/material.dart';
import 'custom_navigation_util.dart';

// CustomNavigationUtil 사용 예제
void main() {
  runApp(const NavigationExampleApp());
}

class NavigationExampleApp extends StatelessWidget {
  const NavigationExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NavigationUtil 예제',
      initialRoute: '/',
      routes: {
        '/': (context) => const HomePage(),
        '/detail': (context) => const DetailPage(),
        '/settings': (context) => const SettingsPage(),
      },
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('홈')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                // Get.to와 유사
                CustomNavigationUtil.to(context, const NextPage());
              },
              child: const Text('to() - 새 페이지로 이동'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // .then() 사용 예제
                CustomNavigationUtil.to(context, const NextPage()).then((
                  result,
                ) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('반환값: $result')));
                });
              },
              child: const Text('to().then() - 반환값 처리'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                // await 사용 예제
                final result = await CustomNavigationUtil.to(
                  context,
                  const NextPage(),
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('반환값: $result')));
                }
              },
              child: const Text('await to() - 비동기 처리'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // Get.toNamed와 유사
                CustomNavigationUtil.toNamed(
                  context,
                  '/detail',
                  arguments: {'id': 123, 'name': '상세 페이지'},
                );
              },
              child: const Text('toNamed() - 라우트로 이동'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // Get.off와 유사
                CustomNavigationUtil.off(context, const NextPage());
              },
              child: const Text('off() - 현재 페이지 대체'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // Get.offNamed와 유사
                CustomNavigationUtil.offNamed(context, '/settings');
              },
              child: const Text('offNamed() - 라우트로 대체'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // Get.offAll와 유사
                CustomNavigationUtil.offAll(context, const NextPage());
              },
              child: const Text('offAll() - 모든 페이지 제거 후 이동'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // Get.offAllNamed와 유사
                CustomNavigationUtil.offAllNamed(context, '/');
              },
              child: const Text('offAllNamed() - 모든 페이지 제거 후 라우트로 이동'),
            ),
          ],
        ),
      ),
    );
  }
}

class NextPage extends StatelessWidget {
  const NextPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('다음 페이지')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                // Get.back와 유사
                CustomNavigationUtil.back(context, result: '반환값');
              },
              child: const Text('back() - 이전 페이지로'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // Get.until와 유사
                CustomNavigationUtil.until(
                  context,
                  (route) => route.settings.name == '/',
                );
              },
              child: const Text('until() - 홈까지 뒤로 가기'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // Get.untilNamed와 유사
                CustomNavigationUtil.untilNamed(context, '/');
              },
              child: const Text('untilNamed() - 홈까지 뒤로 가기'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // Get.untilFirst와 유사
                CustomNavigationUtil.untilFirst(context);
              },
              child: const Text('untilFirst() - 첫 페이지까지'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                final route = CustomNavigationUtil.currentRoute(context);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('현재 라우트: $route')));
              },
              child: const Text('currentRoute() - 현재 라우트 확인'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                final canPop = CustomNavigationUtil.canPop(context);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('뒤로 갈 수 있나: $canPop')));
              },
              child: const Text('canPop() - 뒤로 갈 수 있는지 확인'),
            ),
          ],
        ),
      ),
    );
  }
}

class DetailPage extends StatelessWidget {
  const DetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    // arguments 가져오기
    final args = CustomNavigationUtil.arguments<Map<String, dynamic>>(context);
    final id = args?['id'];
    final name = args?['name'];

    return Scaffold(
      appBar: AppBar(title: const Text('상세 페이지')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('ID: $id'),
            Text('이름: $name'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                CustomNavigationUtil.back(context);
              },
              child: const Text('뒤로 가기'),
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            CustomNavigationUtil.back(context);
          },
          child: const Text('뒤로 가기'),
        ),
      ),
    );
  }
}
