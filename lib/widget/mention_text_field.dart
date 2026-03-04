// mention_text_field.dart
// @ 입력 시 멤버 선택 인라인 드롭다운(Overlay)을 표시하는 TextField

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:syncflow/model/board.dart';
import 'package:syncflow/theme/app_theme_colors.dart';
import 'package:syncflow/util/config_ui.dart';

/// @ 입력 시 보드 멤버 목록을 오버레이로 표시하고, 선택 시 @email 삽입
class MentionTextField extends StatefulWidget {
  const MentionTextField({
    super.key,
    required this.controller,
    required this.boardId,
    required this.members,
    this.decoration,
    this.maxLines = 5,
    this.maxLength,
    this.maxLengthEnforcement = MaxLengthEnforcement.none,
    this.enabled = true,
    this.inputFormatters,
    this.onChanged,
  });

  final TextEditingController controller;
  final int boardId;
  final List<BoardMemberItem> members;
  final InputDecoration? decoration;
  final int maxLines;
  final int? maxLength;
  final MaxLengthEnforcement maxLengthEnforcement;
  final bool enabled;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;

  @override
  State<MentionTextField> createState() => _MentionTextFieldState();
}

class _MentionTextFieldState extends State<MentionTextField> {
  final GlobalKey _fieldKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  static const int _maxOverlayItems = 6;
  static const double _overlayItemHeight = 64;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _removeOverlay();
    super.dispose();
  }

  void _onTextChanged() {
    _updateMentionOverlay();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  /// @ 위치와 커서 기준으로 멘션 쿼리 추출. null이면 오버레이 숨김.
  ({int start, String query})? _getMentionQuery() {
    final text = widget.controller.text;
    final offset = widget.controller.selection.baseOffset;
    if (offset < 0 || offset > text.length) return null;
    if (offset == 0) return null;

    final atIndex = text.lastIndexOf('@', offset - 1);
    if (atIndex < 0) return null;

    final afterAt = text.substring(atIndex + 1, offset);
    if (afterAt.contains(' ') || afterAt.contains('@')) return null;

    return (start: atIndex, query: afterAt.toLowerCase());
  }

  void _updateMentionOverlay() {
    final query = _getMentionQuery();
    if (query == null) {
      _removeOverlay();
      return;
    }

    final filtered = widget.members.where((m) {
      final q = query.query;
      if (q.isEmpty) return true;
      return m.email.toLowerCase().contains(q) ||
          m.display.toLowerCase().contains(q);
    }).toList();

    if (filtered.isEmpty) {
      _removeOverlay();
      return;
    }

    _showOverlay(filtered, query.start);
  }

  void _showOverlay(List<BoardMemberItem> items, int replaceStart) {
    _removeOverlay();

    final renderBox = _fieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;

    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    final overlay = Overlay.of(context);
    _overlayEntry = OverlayEntry(
      builder: (ctx) => _MentionOverlay(
        position: position,
        fieldSize: size,
        items: items,
        maxItems: _maxOverlayItems,
        itemHeight: _overlayItemHeight,
        onSelect: (email) {
          _insertMention(replaceStart, email);
          _removeOverlay();
        },
        onDismiss: _removeOverlay,
      ),
    );
    overlay.insert(_overlayEntry!);
  }

  void _insertMention(int start, String email) {
    final text = widget.controller.text;
    final offset = widget.controller.selection.baseOffset;
    final end = offset.clamp(0, text.length);
    final before = text.substring(0, start);
    final after = text.substring(end);
    final insert = '@$email ';
    final newText = '$before$insert$after';
    widget.controller.text = newText;
    widget.controller.selection = TextSelection.collapsed(offset: start + insert.length);
    widget.onChanged?.call(newText);
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: _fieldKey,
      child: TextField(
        controller: widget.controller,
        decoration: widget.decoration,
        maxLines: widget.maxLines,
        maxLength: widget.maxLength,
        maxLengthEnforcement: widget.maxLengthEnforcement,
        enabled: widget.enabled,
        inputFormatters: widget.inputFormatters,
        onChanged: widget.onChanged,
      ),
    );
  }
}

/// 멘션 선택 오버레이
class _MentionOverlay extends StatelessWidget {
  const _MentionOverlay({
    required this.position,
    required this.fieldSize,
    required this.items,
    required this.maxItems,
    required this.itemHeight,
    required this.onSelect,
    required this.onDismiss,
  });

  final Offset position;
  final Size fieldSize;
  final List<BoardMemberItem> items;
  final int maxItems;
  final double itemHeight;
  final ValueChanged<String> onSelect;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final p = context.appTheme;
    final desiredHeight = (items.length.clamp(0, maxItems) * itemHeight).toDouble();
    final screenHeight = MediaQuery.of(context).size.height;
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final keyboardTop = screenHeight - keyboardInset;

    const margin = 8.0;
    const gap = 4.0;
    final belowTop = position.dy + fieldSize.height + gap;
    final aboveTopBase = position.dy - gap;

    final availableBelow = (keyboardTop - belowTop - margin).clamp(0.0, screenHeight);
    final availableAbove = (aboveTopBase - margin).clamp(0.0, screenHeight);

    final showBelow = availableBelow >= itemHeight || availableBelow >= availableAbove;
    final maxHeight = showBelow ? availableBelow : availableAbove;
    if (maxHeight <= 0) {
      return const SizedBox.shrink();
    }

    final height = desiredHeight.clamp(itemHeight, maxHeight).toDouble();
    final top = showBelow ? belowTop : (position.dy - gap - height);

    return Stack(
      children: [
        GestureDetector(
          onTap: onDismiss,
          behavior: HitTestBehavior.opaque,
          child: const SizedBox.expand(),
        ),
        Positioned(
          left: position.dx,
          top: top,
          width: fieldSize.width,
          child: Material(
            elevation: 8,
            borderRadius: ConfigUI.cardRadius,
            color: p.cardBackground,
            child: Container(
              constraints: BoxConstraints(maxHeight: height),
              decoration: BoxDecoration(
                borderRadius: ConfigUI.cardRadius,
                border: Border.all(color: p.divider),
              ),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final m = items[index];
                  return ListTile(
                    dense: false,
                    visualDensity: VisualDensity.standard,
                    isThreeLine: true,
                    title: Text(
                      m.email,
                      softWrap: true,
                      style: TextStyle(
                        fontSize: ConfigUI.fontSizeBody,
                        color: p.textPrimary,
                      ),
                    ),
                    subtitle: m.display != m.email
                        ? Text(
                            m.display,
                            style: TextStyle(
                              fontSize: ConfigUI.fontSizeCaption,
                              color: p.textSecondary,
                            ),
                          )
                        : null,
                    onTap: () => onSelect(m.email),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
