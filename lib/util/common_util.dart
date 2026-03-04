import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:syncflow/navigation/custom_navigation_util.dart';
import 'package:syncflow/theme/app_theme_colors.dart';
import 'package:syncflow/util/config_ui.dart';

// ─── API Base URL ────────────────────────────────────────────────────────────

/// FastAPI 서버 기본 URL (커스텀 오버라이드)
/// Windows + Android 에뮬레이터 사용자는 자신의 호스트 IP를 설정하세요
/// 예: 'http://192.168.1.50:8000'
/// null이면 플랫폼에 따라 자동 선택 (Android: 10.0.2.2, iOS: 127.0.0.1)
// 로컬 개발: null → 127.0.0.1:8000
// TODO 완료 후 점검 → 서버 업데이트 시 원격 URL로 변경
const String? customApiBaseUrl = null;
// const String? customApiBaseUrl = 'http://cheng80.myqnapcloud.com:18003';
// const String? customApiBaseUrl = 'http://192.168.90.7:8000';

/// 플랫폼별 기본 API Base URL 반환
/// - Android 에뮬레이터: 10.0.2.2 (호스트 머신 루프백)
/// - iOS 시뮬레이터 / 기타: 127.0.0.1
String _getApiBaseUrlSync() {
  if (Platform.isAndroid) {
    return 'http://10.0.2.2:8000';
  }
  return 'http://127.0.0.1:8000';
}

/// FastAPI 서버 기본 URL
///
/// customApiBaseUrl이 설정되어 있으면 사용하고, 없으면 플랫폼에 따라 기본값 반환
String getApiBaseUrl() {
  if (customApiBaseUrl != null && customApiBaseUrl!.isNotEmpty) {
    return customApiBaseUrl!;
  }
  return _getApiBaseUrlSync();
}

/// 최상위 ScaffoldMessenger에 접근하기 위한 글로벌 키.
/// MaterialApp의 messengerKey에 연결하면, 여러 컨텍스트에서 스낵바를
/// 일관된 위치로 표시할 수 있습니다.
/// 참고: showModalBottomSheet는 별도 라우트이므로 스낵바는 그 아래에 표시됩니다.
final GlobalKey<ScaffoldMessengerState> rootMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// 최상위 Overlay에 접근하기 위한 글로벌 키.
/// showOverlaySnackBar: 바텀시트/드로어 위에 표시 (root overlay insert)
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

OverlayEntry? _overlaySnackEntry;

/// 공통 스낵바 표시 헬퍼.
/// - rootMessengerKey가 연결되어 있으면 최상위 스캐폴드에 표시합니다.
/// - 연결되지 않은 경우, 전달받은 context의 ScaffoldMessenger를 사용합니다.
/// - textColor 미지정 시 배경 밝기에 따라 자동 선택 (다크 모드 대응)
void showCommonSnackBar(
  BuildContext context, {
  required String message,
  Color backgroundColor = Colors.black,
  Color? textColor,
  Duration duration = const Duration(seconds: 2),
  SnackBarAction? action,
  bool clearBeforeShow = false,
}) {
  final effectiveTextColor =
      textColor ??
      (backgroundColor.computeLuminance() > 0.5
          ? Colors.black87
          : Colors.white);
  final messenger =
      rootMessengerKey.currentState ?? ScaffoldMessenger.of(context);
  if (clearBeforeShow) {
    messenger.clearSnackBars();
  }
  messenger.showSnackBar(
    SnackBar(
      content: Text(message, style: TextStyle(color: effectiveTextColor)),
      backgroundColor: backgroundColor,
      duration: duration,
      action: action,
    ),
  );
}

/// Overlay 기반 커스텀 스낵바.
/// rootNavigatorKey.currentState?.overlay에 insert → 드로어/바텀시트 위에 표시
void showOverlaySnackBar(
  BuildContext context, {
  required String message,
  Color backgroundColor = Colors.black,
  Duration duration = const Duration(seconds: 2),
  EdgeInsetsGeometry margin = const EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 12,
  ),
}) {
  final overlay =
      rootNavigatorKey.currentState?.overlay ??
      Overlay.of(context, rootOverlay: true);

  _overlaySnackEntry?.remove();
  _overlaySnackEntry = null;

  _overlaySnackEntry = OverlayEntry(
    builder: (context) {
      return Positioned(
        left: 0,
        right: 0,
        bottom: MediaQuery.of(context).viewInsets.bottom,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: margin,
            child: _OverlaySnackBar(
              message: message,
              backgroundColor: backgroundColor,
            ),
          ),
        ),
      );
    },
  );

  overlay.insert(_overlaySnackEntry!);

  Future<void>.delayed(duration, () {
    _overlaySnackEntry?.remove();
    _overlaySnackEntry = null;
  });
}

class _OverlaySnackBar extends StatefulWidget {
  final String message;
  final Color backgroundColor;

  const _OverlaySnackBar({
    required this.message,
    required this.backgroundColor,
  });

  @override
  State<_OverlaySnackBar> createState() => _OverlaySnackBarState();
}

class _OverlaySnackBarState extends State<_OverlaySnackBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _offset = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _offset,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: ConfigUI.paddingCard,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: widget.backgroundColor,
            borderRadius: ConfigUI.buttonRadius,
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            widget.message,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }
}

/// 공통 확인 다이얼로그 헬퍼.
/// - useRootNavigator를 true로 두면 바텀시트 위로 안전하게 표시됩니다.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String? cancelLabel,
  String? confirmLabel,
  Color confirmColor = Colors.red,
  bool useRootNavigator = true,
}) async {
  final p = context.appTheme;
  final result = await showDialog<bool>(
    context: context,
    useRootNavigator: useRootNavigator,
    builder: (context) => AlertDialog(
      backgroundColor: p.sheetBackground,
      title: Text(title, style: TextStyle(color: p.textOnSheet)),
      content: Text(message, style: TextStyle(color: p.iconOnSheet)),
      actions: [
        TextButton(
          onPressed: () => CustomNavigationUtil.back(context, result: false),
          child: Text(
            cancelLabel ?? context.tr('cancel'),
            style: TextStyle(color: p.iconOnSheet),
          ),
        ),
        TextButton(
          onPressed: () => CustomNavigationUtil.back(context, result: true),
          child: Text(
            confirmLabel ?? context.tr('confirm'),
            style: TextStyle(color: confirmColor),
          ),
        ),
      ],
    ),
  );

  return result ?? false;
}
