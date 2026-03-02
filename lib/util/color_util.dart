// color_util.dart
// 색상 관련 유틸

import 'package:flutter/material.dart';

/// 배경색에 대비되는 텍스트 색 (밝으면 검정, 어두우면 흰색)
Color contrastColor(Color bg) {
  final luminance = bg.computeLuminance();
  return luminance > 0.5 ? Colors.black87 : Colors.white;
}
