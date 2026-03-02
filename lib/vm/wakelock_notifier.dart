// wakelock_notifier.dart
// 화면 꺼짐 방지(wakelock) 상태 관리

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncflow/util/app_storage.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// 화면 꺼짐 방지 상태를 관리하는 Notifier
class WakelockNotifier extends Notifier<bool> {
  @override
  bool build() {
    return AppStorage.getWakelockEnabled();
  }

  /// 화면 꺼짐 방지 토글
  Future<void> toggle() async {
    final next = !state;
    state = next;
    await AppStorage.setWakelockEnabled(next);
    debugPrint('toggle: $next');
    if (next) {
      await WakelockPlus.enable();
    } else {
      await WakelockPlus.disable();
    }
  }
}

/// 화면 꺼짐 방지 Notifier Provider
final wakelockNotifierProvider = NotifierProvider<WakelockNotifier, bool>(
  WakelockNotifier.new,
);
