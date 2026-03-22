// app_flow_providers.dart
// 게스트/환영 화면 진입용 Riverpod (M1)

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;

import 'package:syncflow/util/app_storage.dart';
import 'package:syncflow/util/session_secure_storage.dart';

/// GetStorage와 동기. 게스트 "둘러보기" 중일 때 true.
final guestBrowsingProvider = StateProvider<bool>(
  (ref) => AppStorage.getGuestBrowsingActive(),
);

/// 환영 화면에서 "이메일로 로그인"을 눌렀을 때 true → Login 표시.
final showLoginFromWelcomeProvider = StateProvider<bool>((ref) => false);

/// Secure Storage 비동기 조회 (최초 진입 라우팅용).
final hasEverLoggedInProvider = FutureProvider<bool>((ref) async {
  return SessionSecureStorage.getHasEverLoggedIn();
});
