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
import 'package:syncflow/view/auth/login_screen.dart';
import 'package:syncflow/view/main_scaffold.dart';
import 'package:syncflow/vm/session_notifier.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:syncflow/theme/app_theme_colors.dart';
import 'package:syncflow/vm/theme_notifier.dart';

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
  runZonedGuarded(() async {
    await _main();
  }, (error, stack) {
    if (error.toString().contains('WebSocket') ||
        error.toString().contains('Connection was not upgraded')) {
      // WebSocket 미지원 서버(프록시 등): REST만 사용
      return;
    }
    // 기타 비동기 에러는 콘솔에 출력
    debugPrint('Unhandled: $error\n$stack');
  });
}

Future<void> _main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  await EasyLocalization.ensureInitialized();
  await _initDateFormats();

  await GetStorage.init();

  // iOS: Keychain은 앱 삭제 후에도 유지됨. GetStorage는 삭제됨.
  // hasAppLaunchedBefore 없음 = 재설치 → Secure Storage(세션) 초기화 → Android/iOS 동작 일치
  if (!AppStorage.hasAppLaunchedBefore) {
    await SessionSecureStorage.clearSession();
    await AppStorage.setAppHasLaunched();
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
      child: const ProviderScope(child: MyApp()),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    appLocaleForInit = context.locale;
    final themeMode = ref.watch(themeNotifierProvider);
    final sessionAsync = ref.watch(sessionNotifierProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
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
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppThemeColors.darkBackground,
        colorScheme: ColorScheme.dark(
          primary: Colors.white,
          onPrimary: const Color(0xFF1A1A1A),
          surface: AppThemeColors.darkBackground,
          onSurface: Colors.white,
        ),
      ),
      home: sessionAsync.when(
        loading: () => const _SessionLoadingScreen(),
        error: (e, st) => const LoginScreen(),
        data: (session) =>
            session.isLoggedIn ? const MainScaffold() : const LoginScreen(),
      ),
    );
  }
}

/// 세션 로드 중 표시 (Secure Storage 비동기 읽기)
class _SessionLoadingScreen extends StatelessWidget {
  const _SessionLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
