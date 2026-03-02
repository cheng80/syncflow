// sheet_util.dart
// BottomSheet 공통 스타일

import 'package:flutter/material.dart';
import 'package:syncflow/util/config_ui.dart';

/// 기본 BottomSheet 모양 (둥근 상단 모서리)
ShapeBorder get defaultSheetShape => RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(ConfigUI.radiusSheet),
      ),
    );
