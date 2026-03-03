part of 'package:syncflow/view/board_detail_screen.dart';
// 초대 코드 생성 및 공유 UI
//
// [구조 하이라키]
// _InviteButton
// └─ _InviteCodeSheet(코드 표시/복사)

/// 초대 코드 발급 버튼(오너 전용 노출).
class _InviteButton extends ConsumerStatefulWidget {
  const _InviteButton({required this.boardId});

  final int boardId;

  @override
  ConsumerState<_InviteButton> createState() => _InviteButtonState();
}

class _InviteButtonState extends ConsumerState<_InviteButton> {
  bool _loading = false;

  /// 서버에서 초대 코드를 발급받아 시트로 노출한다.
  Future<void> _showInviteSheet() async {
    final session = ref.read(sessionNotifierProvider).value;
    final token = session?.sessionToken;
    if (token == null) return;

    setState(() => _loading = true);
    try {
      final invite = await ref.read(boardHandlerProvider).createInvite(token, widget.boardId);
      if (!mounted) return;
      _loading = false;
      setState(() {});

      showModalBottomSheet(
        context: context,
        builder: (ctx) => _InviteCodeSheet(
          code: invite.code,
          expiresAt: invite.expiresAt,
        ),
      );
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  /// 로딩 상태/아이콘을 포함한 초대 버튼 렌더링.
  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: _loading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.person_add),
      onPressed: _loading ? null : _showInviteSheet,
      tooltip: context.tr('inviteMember'),
    );
  }
}

/// 발급된 초대 코드를 표시하고 복사/공유 액션을 제공하는 시트.
class _InviteCodeSheet extends StatelessWidget {
  const _InviteCodeSheet({required this.code, required this.expiresAt});

  final String code;
  final String expiresAt;

  /// 코드 표시 영역과 액션 버튼을 렌더링한다.
  @override
  Widget build(BuildContext context) {
    final p = context.appTheme;
    return Padding(
      padding: const EdgeInsets.all(ConfigUI.sheetPaddingH),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr('inviteMember'),
            style: TextStyle(
              fontSize: ConfigUI.fontSizeSubtitle,
              fontWeight: FontWeight.bold,
              color: p.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.tr('inviteShareHint'),
            style: TextStyle(fontSize: ConfigUI.fontSizeBody, color: p.textSecondary),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            decoration: BoxDecoration(
              color: p.cardBackground,
              borderRadius: ConfigUI.cardRadius,
              border: Border.all(color: p.divider),
            ),
            child: Center(
              child: Text(
                code,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                  color: p.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(context.tr('inviteCodeCopied'))),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  label: Text(context.tr('copy')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: code));
                    CustomNavigationUtil.back(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(context.tr('inviteCodeCopied'))),
                    );
                  },
                  icon: const Icon(Icons.share, size: 18),
                  label: Text(context.tr('copyAndClose')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// WebSocket 연결 상태 표시 (초록=연결됨, 회색=끊김)
