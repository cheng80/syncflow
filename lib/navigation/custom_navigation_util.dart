import 'package:flutter/material.dart';

// 페이지 전환 애니메이션 타입
enum PageTransitionType {
  // 슬라이드 애니메이션 (기본값)
  slide,

  // 페이드 애니메이션
  fade,

  // 없음 (즉시 전환)
  none,
}

// 스와이프 백 제스처가 비활성화된 PageRoute
// PopScope를 사용하여 iOS 스와이프 백만 차단 (뒤로가기 버튼은 허용)
class _NoSwipeBackPageRoute<T> extends PageRouteBuilder<T> {
  _NoSwipeBackPageRoute({
    required WidgetBuilder builder,
    super.settings,
    PageTransitionType transitionType = PageTransitionType.slide,
  }) : super(
        pageBuilder: (context, animation, secondaryAnimation) {
          // PopScope로 감싸서 스와이프 백 제스처만 차단 (뒤로가기 버튼은 허용)
          // canPop을 동적으로 확인하여 AppBar의 뒤로 가기 버튼이 작동하도록 함
          // 스와이프 백 제스처는 onPopInvokedWithResult에서 차단
          return Builder(
            builder: (builderContext) {
              return PopScope(
                canPop: Navigator.canPop(builderContext),
                onPopInvokedWithResult: (bool didPop, dynamic result) {
                  // didPop이 false인 경우: 스와이프 백 제스처로 인한 pop 시도 (차단됨)
                  // didPop이 true인 경우: Navigator.pop() 또는 AppBar 뒤로 가기 버튼으로 인한 pop (정상 동작)
                  if (!didPop) {
                    // 스와이프 백 제스처는 차단 (아무 작업도 하지 않음)
                    // AppBar의 뒤로 가기 버튼은 canPop이 true이므로 정상 작동
                    return;
                  }
                  // Navigator.pop() 또는 AppBar 뒤로 가기 버튼으로 인한 pop은 이미 완료되었으므로
                  // 추가 작업 불필요
                },
                child: builder(context),
              );
            },
          );
        },
         // fullscreenDialog: true 제거 (이것이 X 아이콘을 표시하는 원인)
         transitionsBuilder: (context, animation, secondaryAnimation, child) {
           switch (transitionType) {
             case PageTransitionType.slide:
               // 슬라이드 애니메이션
               const begin = Offset(1.0, 0.0);
               const end = Offset.zero;
               const curve = Curves.ease;

               var tween = Tween(
                 begin: begin,
                 end: end,
               ).chain(CurveTween(curve: curve));

               return SlideTransition(
                 position: animation.drive(tween),
                 child: child,
               );
             case PageTransitionType.fade:
               // 페이드 애니메이션
               return FadeTransition(opacity: animation, child: child);
             case PageTransitionType.none:
               // 애니메이션 없음 - animation을 무시하고 항상 완료된 상태로 표시
               return child;
           }
         },
         transitionDuration: transitionType == PageTransitionType.none
             ? Duration.zero
             : const Duration(milliseconds: 300),
         reverseTransitionDuration: transitionType == PageTransitionType.none
             ? Duration.zero
             : const Duration(milliseconds: 300),
       );
}

// 네비게이션 유틸리티 클래스
// GetX의 Get.to, Get.toNamed 등과 유사한 기능을 제공합니다.
class CustomNavigationUtil {
  // ============================================
  // 기본 네비게이션 기능
  // ============================================

  // 새 페이지로 이동 (Get.to와 유사)
  //
  // [enableSwipeBack]: 스와이프 백 제스처 활성화 여부 (기본값: false)
  // [transitionType]: 페이지 전환 애니메이션 타입 (기본값: PageTransitionType.slide)
  //
  // 사용 예시:
  // ```dart
  // // 기본 사용 (스와이프 백 비활성화, 슬라이드 애니메이션)
  // CustomNavigationUtil.to(
  //   context,
  //   const NextPage(),
  // );
  //
  // // 스와이프 백 활성화
  // CustomNavigationUtil.to(
  //   context,
  //   const NextPage(),
  //   enableSwipeBack: true,
  // );
  //
  // // 페이드 애니메이션 사용
  // CustomNavigationUtil.to(
  //   context,
  //   const NextPage(),
  //   transitionType: PageTransitionType.fade,
  // );
  //
  // // 애니메이션 없음
  // CustomNavigationUtil.to(
  //   context,
  //   const NextPage(),
  //   transitionType: PageTransitionType.none,
  // );
  //
  // // .then() 사용
  // CustomNavigationUtil.to(context, const NextPage())
  //   .then((result) {
  //     print('반환값: $result');
  //   });
  //
  // // await 사용
  // final result = await CustomNavigationUtil.to(context, const NextPage());
  // print('반환값: $result');
  // ```
  static Future<T?> to<T extends Object?>(
    BuildContext context,
    Widget page, {
    RouteSettings? settings,
    bool enableSwipeBack = false,
    PageTransitionType transitionType = PageTransitionType.slide,
  }) {
    if (enableSwipeBack) {
      return Navigator.push<T>(
        context,
        MaterialPageRoute<T>(builder: (context) => page, settings: settings),
      );
    } else {
      return Navigator.push<T>(
        context,
        _NoSwipeBackPageRoute<T>(
          builder: (context) => page,
          settings: settings,
          transitionType: transitionType,
        ),
      );
    }
  }

  // 라우트 이름으로 이동 (Get.toNamed와 유사)
  //
  // 사용 예시:
  // ```dart
  // // 기본 사용
  // CustomNavigationUtil.toNamed(
  //   context,
  //   '/detail',
  //   arguments: {'id': 123},
  // );
  //
  // // .then() 사용
  // CustomNavigationUtil.toNamed(context, '/detail')
  //   .then((result) {
  //     print('반환값: $result');
  //   });
  //
  // // await 사용
  // final result = await CustomNavigationUtil.toNamed(context, '/detail');
  // ```
  static Future<T?> toNamed<T extends Object?>(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) {
    return Navigator.pushNamed<T>(context, routeName, arguments: arguments);
  }

  // 현재 페이지를 대체하고 이동 (Get.off와 유사)
  //
  // [enableSwipeBack]: 스와이프 백 제스처 활성화 여부 (기본값: false)
  // [transitionType]: 페이지 전환 애니메이션 타입 (기본값: PageTransitionType.slide)
  //
  // 사용 예시:
  // ```dart
  // // 기본 사용 (스와이프 백 비활성화, 슬라이드 애니메이션)
  // CustomNavigationUtil.off(
  //   context,
  //   const NextPage(),
  // );
  //
  // // 스와이프 백 활성화
  // CustomNavigationUtil.off(
  //   context,
  //   const NextPage(),
  //   enableSwipeBack: true,
  // );
  //
  // // 페이드 애니메이션 사용
  // CustomNavigationUtil.off(
  //   context,
  //   const NextPage(),
  //   transitionType: PageTransitionType.fade,
  // );
  // ```
  static Future<T?> off<T extends Object?>(
    BuildContext context,
    Widget page, {
    RouteSettings? settings,
    bool enableSwipeBack = false,
    PageTransitionType transitionType = PageTransitionType.slide,
  }) {
    if (transitionType == PageTransitionType.none) {
      // 애니메이션 없이 즉시 전환
      return Navigator.pushReplacement<T, void>(
        context,
        PageRouteBuilder<T>(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          settings: settings,
        ),
      );
    } else if (enableSwipeBack) {
      return Navigator.pushReplacement<T, void>(
        context,
        MaterialPageRoute<T>(builder: (context) => page, settings: settings),
      );
    } else {
      return Navigator.pushReplacement<T, void>(
        context,
        _NoSwipeBackPageRoute<T>(
          builder: (context) => page,
          settings: settings,
          transitionType: transitionType,
        ),
      );
    }
  }

  // 현재 페이지를 대체하고 라우트로 이동 (Get.offNamed와 유사)
  //
  // 사용 예시:
  // ```dart
  // CustomNavigationUtil.offNamed(
  //   context,
  //   '/login',
  //   arguments: {'from': 'home'},
  // );
  // ```
  static Future<T?> offNamed<T extends Object?, TO extends Object?>(
    BuildContext context,
    String routeName, {
    Object? arguments,
    TO? result,
  }) {
    return Navigator.pushReplacementNamed<T, TO>(
      context,
      routeName,
      arguments: arguments,
      result: result,
    );
  }

  // 모든 페이지를 제거하고 이동 (Get.offAll와 유사)
  //
  // [enableSwipeBack]: 스와이프 백 제스처 활성화 여부 (기본값: false)
  // [transitionType]: 페이지 전환 애니메이션 타입 (기본값: PageTransitionType.slide)
  //
  // 사용 예시:
  // ```dart
  // // 기본 사용 (스와이프 백 비활성화, 슬라이드 애니메이션)
  // CustomNavigationUtil.offAll(
  //   context,
  //   const HomePage(),
  // );
  //
  // // 스와이프 백 활성화
  // CustomNavigationUtil.offAll(
  //   context,
  //   const HomePage(),
  //   enableSwipeBack: true,
  // );
  //
  // // 페이드 애니메이션 사용
  // CustomNavigationUtil.offAll(
  //   context,
  //   const HomePage(),
  //   transitionType: PageTransitionType.fade,
  // );
  // ```
  static Future<T?> offAll<T extends Object?>(
    BuildContext context,
    Widget page, {
    RouteSettings? settings,
    bool enableSwipeBack = false,
    PageTransitionType transitionType = PageTransitionType.slide,
  }) {
    if (enableSwipeBack) {
      return Navigator.pushAndRemoveUntil<T>(
        context,
        MaterialPageRoute<T>(builder: (context) => page, settings: settings),
        (route) => false,
      );
    } else {
      return Navigator.pushAndRemoveUntil<T>(
        context,
        _NoSwipeBackPageRoute<T>(
          builder: (context) => page,
          settings: settings,
          transitionType: transitionType,
        ),
        (route) => false,
      );
    }
  }

  // 모든 페이지를 제거하고 라우트로 이동 (Get.offAllNamed와 유사)
  //
  // 사용 예시:
  // ```dart
  // CustomNavigationUtil.offAllNamed(
  //   context,
  //   '/home',
  // );
  // ```
  static Future<T?> offAllNamed<T extends Object?>(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) {
    return Navigator.pushNamedAndRemoveUntil<T>(
      context,
      routeName,
      (route) => false,
      arguments: arguments,
    );
  }

  // 이전 페이지로 돌아가기 (Get.back와 유사)
  //
  // 사용 예시:
  // ```dart
  // CustomNavigationUtil.back(
  //   context,
  //   result: '반환값',
  // );
  // ```
  static void back<T extends Object?>(BuildContext context, {T? result}) {
    Navigator.pop<T>(context, result);
  }

  // 특정 조건까지 뒤로 가기 (Get.until와 유사)
  //
  // 사용 예시:
  // ```dart
  // CustomNavigationUtil.until(
  //   context,
  //   (route) => route.settings.name == '/home',
  // );
  // ```
  static void until(
    BuildContext context,
    bool Function(Route<dynamic>) predicate,
  ) {
    Navigator.popUntil(context, predicate);
  }

  // 특정 라우트까지 뒤로 가기
  //
  // 사용 예시:
  // ```dart
  // CustomNavigationUtil.untilNamed(
  //   context,
  //   '/home',
  // );
  // ```
  static void untilNamed(BuildContext context, String routeName) {
    Navigator.popUntil(context, (route) => route.settings.name == routeName);
  }

  // 첫 번째 페이지까지 뒤로 가기
  //
  // 사용 예시:
  // ```dart
  // CustomNavigationUtil.untilFirst(
  //   context,
  // );
  // ```
  static void untilFirst(BuildContext context) {
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  // 현재 라우트 이름 가져오기
  //
  // 사용 예시:
  // ```dart
  // final currentRoute = CustomNavigationUtil.currentRoute(context);
  // print('현재 라우트: $currentRoute');
  // ```
  static String? currentRoute(BuildContext context) {
    return ModalRoute.of(context)?.settings.name;
  }

  // 현재 라우트의 arguments 가져오기
  //
  // 사용 예시:
  // ```dart
  // final args = CustomNavigationUtil.arguments<Map<String, dynamic>>(context);
  // final id = args?['id'];
  // ```
  static T? arguments<T extends Object?>(BuildContext context) {
    return ModalRoute.of(context)?.settings.arguments as T?;
  }

  // 특정 라우트로 이동할 수 있는지 확인
  //
  // 사용 예시:
  // ```dart
  // if (CustomNavigationUtil.canPop(context)) {
  //   CustomNavigationUtil.back(context);
  // }
  // ```
  static bool canPop(BuildContext context) {
    return Navigator.canPop(context);
  }

  // 스택에 있는 페이지 수 확인
  //
  // 사용 예시:
  // ```dart
  // final count = CustomNavigationUtil.stackCount(context);
  // print('스택에 $count개의 페이지가 있습니다.');
  // ```
  static int stackCount(BuildContext context) {
    int count = 0;
    Navigator.popUntil(context, (route) {
      count++;
      return route.isFirst;
    });
    // 원래 상태로 복구
    Navigator.popUntil(context, (route) => false);
    return count;
  }
}
