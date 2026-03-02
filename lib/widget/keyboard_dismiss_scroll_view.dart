// keyboard_dismiss_scroll_view.dart
// 텍스트 인풋 화면: 탭 시 키보드 내림 + SingleChildScrollView

import 'package:flutter/material.dart';

/// 텍스트 인풋이 있는 화면용 래퍼
/// - GestureDetector: 포커스 아웃(탭) 시 키보드 내림
/// - SingleChildScrollView: 키보드 노출 시 스크롤 가능
class KeyboardDismissScrollView extends StatelessWidget {
  const KeyboardDismissScrollView({
    super.key,
    required this.child,
    this.padding,
    this.keyboardPadding = true,
  });

  final Widget child;
  final EdgeInsets? padding;
  /// viewInsets.bottom(키보드 높이) 패딩 적용 여부
  final bool keyboardPadding;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      behavior: HitTestBehavior.opaque,
      child: SingleChildScrollView(
        padding: padding ?? (keyboardPadding ? EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom) : null),
        child: child,
      ),
    );
  }
}
