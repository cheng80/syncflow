// main_scaffold.dart
// 메인 스캐폴드 - 홈 화면 표시
//
// [구조 하이라키]
// MainScaffold
// └─ _MainScaffoldState
//    ├─ Showcase 튜토리얼 제어
//    ├─ AppDrawer / BoardListScreen 조립
//    └─ _InAppReviewTrigger(리뷰 트리거 래퍼)

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

  /// 튜토리얼 키를 준비하고 첫 프레임 이후 시작 가능성을 점검한다.
  @override
  void initState() {
    super.initState();
    _tutorialKeys = TutorialKeys();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStartTutorial());
  }

  /// 로컬라이제이션/Showcase 컨텍스트가 준비되면 튜토리얼 등록을 1회 수행한다.
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

  /// 튜토리얼 미완료 사용자에게 Drawer 포함 Showcase를 시작한다.
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

  /// 사용자 요청 시 튜토리얼을 처음부터 다시 시작한다.
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

  /// 등록한 Showcase 리소스를 해제한다.
  @override
  void dispose() {
    if (_showcaseRegistered) {
      ShowcaseView.get().unregister();
    }
    super.dispose();
  }

  /// 메인 스캐폴드(드로어/앱바/보드 목록)를 렌더링한다.
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

  /// 세션당 1회만 인앱 리뷰 요청 체크를 실행한다.
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
