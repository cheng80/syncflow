import 'package:flutter/services.dart';

/// 줄 수 제한 전용 formatter.
/// 최대 줄 수를 초과하는 입력 변경은 무시하고 이전 값을 유지한다.
class MaxLinesTextInputFormatter extends TextInputFormatter {
  MaxLinesTextInputFormatter(this.maxLines) : assert(maxLines > 0);

  final int maxLines;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final lineCount = '\n'.allMatches(newValue.text).length + 1;
    if (lineCount > maxLines) {
      return oldValue;
    }
    return newValue;
  }
}
