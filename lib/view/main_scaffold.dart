// main_scaffold.dart
// 메인 스캐폴드 - 홈 화면 표시

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:syncflow/service/in_app_review_service.dart';
import 'package:syncflow/theme/app_theme_colors.dart';
import 'package:syncflow/util/app_storage.dart';
import 'package:syncflow/util/config_ui.dart';
import 'package:syncflow/util/tutorial_keys.dart';
import 'package:syncflow/view/app_drawer.dart';
import 'package:syncflow/view/board_list_screen.dart';

/// 메인 스캐폴드 - 홈 화면
class MainScaffold extends ConsumerStatefulWidget {
  const MainScaffold({super.key});

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late final TutorialKeys _tutorialKeys;

  bool _showcaseRegistered = false;

  @override
  void initState() {
    super.initState();
    _tutorialKeys = TutorialKeys();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStartTutorial());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_showcaseRegistered) return;
    _showcaseRegistered = true;

    final ctx = context;
    ShowcaseView.register(
      enableShowcase: !AppStorage.getTutorialCompleted(),
      onDismiss: (_) => AppStorage.setTutorialCompleted(),
      onFinish: () => AppStorage.setTutorialCompleted(),
      onComplete: (index, key) {
        // Drawer 단계(0) 완료 후 Drawer 닫기 → 메뉴 버튼(1) 표시
        if (index == 0) {
          _scaffoldKey.currentState?.closeDrawer();
        }
      },
      globalTooltipActionConfig: const TooltipActionConfig(
        alignment: MainAxisAlignment.spaceBetween,
        position: TooltipActionPosition.inside,
      ),
      globalTooltipActions: [
        TooltipActionButton(
          type: TooltipDefaultActionType.skip,
          name: ctx.tr('tutorial_skip'),
          backgroundColor: const Color(0xFF1976D2),
          textStyle: const TextStyle(color: Colors.white),
          onTap: () => ShowcaseView.get().dismiss(),
        ),
        TooltipActionButton(
          type: TooltipDefaultActionType.next,
          name: ctx.tr('tutorial_next'),
          backgroundColor: const Color(0xFF1976D2),
          textStyle: const TextStyle(color: Colors.white),
        ),
      ],
    );
  }

  Future<void> _maybeStartTutorial() async {
    if (AppStorage.getTutorialCompleted() || !mounted) return;

    // Drawer 내 위젯 포함: 먼저 Drawer 열기
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    _scaffoldKey.currentState?.openDrawer();
    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;

    ShowcaseView.get().startShowCase(_tutorialKeys.all);
  }

  void _restartTutorial() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;

      _scaffoldKey.currentState?.openDrawer();
      await Future.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;

      final sv = ShowcaseView.get();
      sv.enableShowcase = true;
      sv.startShowCase(_tutorialKeys.all);
    });
  }

  @override
  void dispose() {
    if (_showcaseRegistered) {
      ShowcaseView.get().unregister();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.appTheme;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: p.background,
      drawer: AppDrawer(
        tutorialKeys: _tutorialKeys,
        onReplayTutorial: _restartTutorial,
      ),
      appBar: AppBar(
        backgroundColor: p.background,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: p.icon),
        leading: Showcase(
          key: _tutorialKeys.menu,
          description: context.tr('tutorial_step_2'),
          tooltipBackgroundColor: p.sheetBackground,
          textColor: p.textOnSheet,
          tooltipBorderRadius: ConfigUI.cardRadius,
          child: IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
        ),
        title: Text(
          context.tr('board'),
          style: TextStyle(color: p.textPrimary, fontSize: ConfigUI.fontSizeAppBar),
        ),
      ),
      body: _InAppReviewTrigger(
        child: BoardListScreen(tutorialKeys: _tutorialKeys),
      ),
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
