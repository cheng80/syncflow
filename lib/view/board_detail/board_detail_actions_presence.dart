part of 'package:syncflow/view/board_detail_screen.dart';
// 접속 상태 점/아바타/참여자 목록 UI
//
// [구조 하이라키]
// _WsConnectionIndicator
// _PresenceAvatarsButton
// ├─ _AvatarDot
// └─ _PresenceMembersSheet

/// WebSocket 연결 상태를 점(녹색/회색)으로 표시한다.
class _WsConnectionIndicator extends ConsumerWidget {
  const _WsConnectionIndicator();

  /// 연결 상태 provider를 구독해 상태 점 UI를 렌더링한다.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(wsConnectionStateProvider);
    return state.when(
      loading: () => _dot(context, false),
      error: (error, stackTrace) => _dot(context, false),
      data: (connected) => Tooltip(
        message: connected ? context.tr('syncConnected') : context.tr('syncDisconnected'),
        child: Padding(
          padding: const EdgeInsets.only(right: 12),
          child: _dot(context, connected),
        ),
      ),
    );
  }

  /// 상태 점 한 개를 렌더링한다.
  Widget _dot(BuildContext context, bool connected) {
    return Container(
      width: 10,
      height: 10,
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: connected ? Colors.green : Colors.grey,
        boxShadow: [
          BoxShadow(
            color: (connected ? Colors.green : Colors.grey).withValues(alpha: 0.5),
            blurRadius: 4,
          ),
        ],
      ),
    );
  }
}

/// 현재 접속자 아바타 스택 버튼.
/// 탭 시 접속자 목록 시트를 연다.
class _PresenceAvatarsButton extends ConsumerWidget {
  const _PresenceAvatarsButton({required this.boardId});

  final int boardId;

  /// 접속자 수에 따라 아바타 스택 또는 빈 위젯을 반환한다.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(presenceMembersProvider(boardId));
    if (members.isEmpty) {
      return const SizedBox.shrink();
    }

    return IconButton(
      tooltip: context.tr('presenceCount', namedArgs: {'count': '${members.length}'}),
      onPressed: () {
        showModalBottomSheet(
          context: context,
          builder: (ctx) => _PresenceMembersSheet(members: members),
        );
      },
      icon: SizedBox(
        width: 64,
        height: 24,
        child: Stack(
          children: [
            for (var i = 0; i < members.length && i < 3; i++)
              Positioned(
                left: i * 16,
                child: _AvatarDot(label: members[i].display),
              ),
            if (members.length > 3)
              Positioned(
                left: 48,
                child: Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    '+${members.length - 3}',
                    style: const TextStyle(fontSize: 9, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 접속자 1인의 이니셜 아바타 점.
class _AvatarDot extends StatelessWidget {
  const _AvatarDot({required this.label});
  final String label;

  /// 표시명 기반 색/이니셜로 아바타를 그린다.
  @override
  Widget build(BuildContext context) {
    final trimmed = label.trim();
    final initial = trimmed.isEmpty
        ? '?'
        : String.fromCharCode(trimmed.runes.first).toUpperCase();
    final colors = [
      const Color(0xFFEF5350),
      const Color(0xFF42A5F5),
      const Color(0xFF66BB6A),
      const Color(0xFFFFA726),
      const Color(0xFFAB47BC),
      const Color(0xFF26A69A),
    ];
    final color = colors[trimmed.hashCode.abs() % colors.length];
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// 현재 접속자 목록을 보여주는 바텀시트.
class _PresenceMembersSheet extends StatelessWidget {
  const _PresenceMembersSheet({required this.members});
  final List<PresenceMember> members;

  /// 접속자 목록 시트 레이아웃을 렌더링한다.
  @override
  Widget build(BuildContext context) {
    final p = context.appTheme;
    return Padding(
      padding: const EdgeInsets.all(ConfigUI.sheetPaddingH),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('presenceConnecting', namedArgs: {'count': '${members.length}'}),
            style: TextStyle(
              fontSize: ConfigUI.fontSizeSubtitle,
              fontWeight: FontWeight.bold,
              color: p.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ...members.map((m) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    _AvatarDot(label: m.display),
                    const SizedBox(width: 10),
                    Text(
                      (m.email != null && m.email!.trim().isNotEmpty)
                          ? m.email!
                          : m.display,
                      style: TextStyle(color: p.textPrimary),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
