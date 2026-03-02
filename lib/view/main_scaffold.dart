// main_scaffold.dart
// 메인 스캐폴드 - 홈 화면 표시

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncflow/service/in_app_review_service.dart';
import 'package:syncflow/theme/app_theme_colors.dart';
import 'package:syncflow/util/config_ui.dart';
import 'package:syncflow/view/app_drawer.dart';
import 'package:syncflow/view/board_list_screen.dart';

/// 메인 스캐폴드 - 홈 화면
class MainScaffold extends ConsumerWidget {
  const MainScaffold({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.appTheme;

    return Scaffold(
      backgroundColor: p.background,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: p.background,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: p.icon),
        title: Text(
          context.tr('board'),
          style: TextStyle(color: p.textPrimary, fontSize: ConfigUI.fontSizeAppBar),
        ),
      ),
      body: const _InAppReviewTrigger(child: BoardListScreen()),
    );
  }
}

/// MainScaffold 진입 시 maybeRequestReview 자동 호출 (가이드: 버튼/CTA 아님)
/// 조건: 첫 실행 3일 경과 + 아직 요청 안 함
class _InAppReviewTrigger extends StatefulWidget {
  const _InAppReviewTrigger({required this.child});

  final Widget child;

  @override
  State<_InAppReviewTrigger> createState() => _InAppReviewTriggerState();
}

class _InAppReviewTriggerState extends State<_InAppReviewTrigger> {
  static bool _triggeredThisSession = false;

  @override
  void initState() {
    super.initState();
    if (_triggeredThisSession) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_triggeredThisSession) return;
      _triggeredThisSession = true;
      // 앱 화면 표시 후 잠시 대기 후 요청 (UX)
      Future.delayed(const Duration(seconds: 2), () {
        InAppReviewService().maybeRequestReview();
      });
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
