// main.dart
// 앱 진입점

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_storage/get_storage.dart';
import 'package:syncflow/util/app_locale.dart';
import 'package:syncflow/util/app_storage.dart';
import 'package:syncflow/util/session_secure_storage.dart';
import 'package:syncflow/view/auth/guest_home_screen.dart';
import 'package:syncflow/view/auth/login_screen.dart';
import 'package:syncflow/view/auth/welcome_screen.dart';
import 'package:syncflow/view/main_scaffold.dart';
import 'package:syncflow/vm/app_flow_providers.dart';
import 'package:syncflow/vm/session_notifier.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:syncflow/theme/app_theme_colors.dart';
import 'package:syncflow/util/common_util.dart';
import 'package:syncflow/vm/theme_notifier.dart';
import 'package:syncflow/vm/fcm_notifier.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:syncflow/firebase_options.dart';

Future<void> _initDateFormats() async {
  await Future.wait([
    initializeDateFormatting('ko_KR'),
    initializeDateFormatting('en_US'),
    initializeDateFormatting('ja_JP'),
    initializeDateFormatting('zh_CN'),
    initializeDateFormatting('zh_TW'),
  ]);
}

void main() async {
  // WebSocket 등 비동기 에러가 앱을 중단하지 않도록 처리
  runZonedGuarded(
    () async {
      await _main();
    },
    (error, stack) {
      if (error.toString().contains('WebSocket') ||
          error.toString().contains('Connection was not upgraded')) {
        // WebSocket 미지원 서버(프록시 등): REST만 사용
        return;
      }
      // 기타 비동기 에러는 콘솔에 출력
      debugPrint('Unhandled: $error\n$stack');
    },
  );
}

Future<void> _main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Firebase 초기화 (실패 시에도 앱 진입 허용)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('[main] Firebase init failed (FCM disabled): $e');
  }

  await EasyLocalization.ensureInitialized();
  await _initDateFormats();

  await GetStorage.init();

  // iOS: Keychain은 앱 삭제 후에도 유지됨. GetStorage는 삭제됨.
  // hasAppLaunchedBefore 없음 = 재설치 → Secure Storage(세션) 초기화 → Android/iOS 동작 일치
  // iOS 실기기: flutter_secure_storage 첫 접근 시 hang 가능 → 타임아웃
  try {
    if (!AppStorage.hasAppLaunchedBefore) {
      await SessionSecureStorage.clearSession().timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          debugPrint('[main] clearSession TIMEOUT');
        },
      );
      await AppStorage.setAppHasLaunched();
    }
  } catch (e) {
    debugPrint('[main] SecureStorage block error: $e');
  }

  // 첫 실행일 저장 (인앱 리뷰 조건용)
  if (AppStorage.getFirstLaunchDate() == null) {
    await AppStorage.saveFirstLaunchDate(DateTime.now());
  }

  FlutterNativeSplash.remove();

  runApp(
    EasyLocalization(
      supportedLocales: const [
        Locale('ko'),
        Locale('en'),
        Locale('ja'),
        Locale('zh', 'CN'),
        Locale('zh', 'TW'),
      ],
      path: 'assets/translations',
      fallbackLocale: const Locale('ko'),
      useFallbackTranslations: true,
      child: const ProviderScope(child: AppBootstrap()),
    ),
  );
}

class AppBootstrap extends ConsumerStatefulWidget {
  const AppBootstrap({super.key});

  @override
  ConsumerState<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends ConsumerState<AppBootstrap> {
  @override
  void initState() {
    super.initState();
    // 세션이 이미 복구된 경우(로그인 상태)에만 FCM 초기화 — 게스트/환영/로그인만인 경우 생략 (M1)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sessionNotifierProvider).maybeWhen(
        data: (session) {
          if (session.isLoggedIn) {
            unawaited(ref.read(fcmNotifierProvider.notifier).initialize());
          }
        },
        orElse: () {},
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(sessionNotifierProvider, (previous, next) {
      next.whenData((session) {
        if (session.isLoggedIn) {
          unawaited(ref.read(fcmNotifierProvider.notifier).initialize());
        }
      });
    });
    return const MyApp();
  }
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    appLocaleForInit = context.locale;
    final themeMode = ref.watch(themeNotifierProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: rootNavigatorKey,
      scaffoldMessengerKey: rootMessengerKey,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      themeMode: themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppThemeColors.lightBackground,
        colorScheme: ColorScheme.light(
          primary: const Color(0xFF1976D2),
          onPrimary: Colors.white,
          surface: AppThemeColors.lightBackground,
          onSurface: const Color(0xFF212121),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.black, width: 3),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.black, width: 3),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Colors.black, width: 3),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Colors.black, width: 3),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Color(0xFF1976D2), width: 3),
          ),
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppThemeColors.darkBackground,
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF1976D2),
          onPrimary: Colors.white,
          surface: AppThemeColors.darkBackground,
          onSurface: Colors.white,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.white70, width: 3),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.white70, width: 3),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Colors.white70, width: 3),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Colors.white70, width: 3),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Color(0xFF1976D2), width: 3),
          ),
        ),
      ),
      home: const _AppRootRouter(),
    );
  }
}

/// 세션 + hasEverLoggedIn + 게스트 플래그로 첫 화면 분기 (M1).
class _AppRootRouter extends ConsumerWidget {
  const _AppRootRouter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(sessionNotifierProvider);
    final hasEverAsync = ref.watch(hasEverLoggedInProvider);

    return sessionAsync.when(
      loading: () => const _SessionLoadingScreen(),
      error: (e, st) => const LoginScreen(),
      data: (session) {
        if (session.isLoggedIn) {
          return const MainScaffold();
        }

        return hasEverAsync.when(
          loading: () => const _SessionLoadingScreen(),
          error: (e, st) => const LoginScreen(),
          data: (hasEver) {
            if (hasEver) {
              return const LoginScreen();
            }
            final guest = ref.watch(guestBrowsingProvider);
            final showLogin = ref.watch(showLoginFromWelcomeProvider);
            if (guest) {
              return const GuestHomeScreen();
            }
            if (showLogin) {
              return const LoginScreen(showBackToWelcome: true);
            }
            return const WelcomeScreen();
          },
        );
      },
    );
  }
}

/// 세션 로드 중 표시 (Secure Storage 비동기 읽기)
class _SessionLoadingScreen extends StatelessWidget {
  const _SessionLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
