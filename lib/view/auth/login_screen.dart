// login_screen.dart
// 이메일 입력 → 코드 발송 → 코드 입력 → 로그인
//
// [구조 하이라키]
// LoginScreen
// └─ _LoginScreenState
//    ├─ _sendCode(인증코드 발송)
//    ├─ _verifyCode(코드 검증/로그인)
//    └─ _goBack(단계 되돌리기)

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:syncflow/service/api_client.dart';
import 'package:syncflow/theme/app_theme_colors.dart';
import 'package:syncflow/util/common_util.dart';
import 'package:syncflow/util/config_ui.dart';
import 'package:syncflow/vm/app_flow_providers.dart';
import 'package:syncflow/vm/session_notifier.dart';
import 'package:syncflow/widget/keyboard_dismiss_scroll_view.dart';
import 'package:syncflow/widget/language_picker_sheet.dart';

/// 로그인 화면
/// Step 1: 이메일 입력 → 코드 발송
/// Step 2: 코드 입력 → 로그인
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.showBackToWelcome = false});

  /// 환영 화면에서 진입 시 뒤로가기로 환영으로 복귀.
  final bool showBackToWelcome;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  String? _email; // 코드 발송 후 저장
  bool _loading = false;
  String? _error;

  /// 입력 컨트롤러 리소스를 해제한다.
  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  /// 이메일 인증 코드를 요청하고 입력 단계로 이동한다.
  Future<void> _sendCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        _error = context.tr('emailRequired');
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ApiClient().sendAuthCode(email);
      setState(() {
        _email = email;
        _loading = false;
        _error = null;
        _codeController.clear();
      });
    } on ApiException catch (e) {
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('sendAuthCode failed: $e');
        debugPrint('baseUrl=${getApiBaseUrl()}');
      }
      setState(() {
        _loading = false;
        _error = kDebugMode ? '${context.tr('sendCodeFailed')}\n$e' : context.tr('sendCodeFailed');
      });
    }
  }

  /// 입력된 인증 코드를 검증하고 세션을 확정한다.
  Future<void> _verifyCode() async {
    final email = _email ?? _emailController.text.trim();
    final code = _codeController.text.trim();
    if (email.isEmpty || code.isEmpty) {
      setState(() {
        _error = context.tr('emailAndCodeRequired');
      });
      return;
    }
    if (code.length != 6) {
      setState(() {
        _error = context.tr('codeMustBe6Digits');
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiClient().verifyAuthCode(email, code);
      await ref.read(sessionNotifierProvider.notifier).loginSuccess(
            res.sessionToken,
            res.expiresAt,
            res.userId,
          );
      ref.read(guestBrowsingProvider.notifier).state = false;
      ref.read(showLoginFromWelcomeProvider.notifier).state = false;
      // 세션 저장 후 루트가 MainScaffold로 전환됨
    } on ApiException catch (e) {
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (_) {
      setState(() {
        _loading = false;
        _error = context.tr('verifyFailed');
      });
    }
  }

  /// 코드 입력 단계에서 이메일 입력 단계로 되돌린다.
  void _goBack() {
    setState(() {
      _email = null;
      _error = null;
      _codeController.clear();
    });
  }

  /// 로그인 화면 전체 UI를 렌더링한다.
  @override
  Widget build(BuildContext context) {
    final p = context.appTheme;
    final isCodeStep = _email != null;

    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        backgroundColor: p.background,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        leading: widget.showBackToWelcome
            ? IconButton(
                icon: Icon(Icons.arrow_back, color: p.icon),
                onPressed: () {
                  ref.read(showLoginFromWelcomeProvider.notifier).state = false;
                },
              )
            : null,
        iconTheme: IconThemeData(color: p.icon),
        actions: [
          IconButton(
            icon: Icon(Icons.language, color: p.icon),
            onPressed: () => showLanguagePickerSheet(context),
            tooltip: context.tr('language'),
          ),
        ],
      ),
      body: SafeArea(
        child: KeyboardDismissScrollView(
          padding: const EdgeInsets.symmetric(horizontal: ConfigUI.screenPaddingH),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GestureDetector(
                    onLongPress: kReleaseMode
                        ? null
                        : () => showApiBaseUrlSettingsSheet(context),
                    child: Text(
                      context.tr('appName'),
                      style: TextStyle(
                        color: p.textPrimary,
                        fontSize: ConfigUI.fontSizeTitle,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.tr('appTagline'),
                    style: TextStyle(
                      color: p.textSecondary,
                      fontSize: ConfigUI.fontSizeBody,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (!isCodeStep) ...[
                    const SizedBox(height: 24),
                    Text(
                      context.tr('loginIntro'),
                      style: TextStyle(
                        color: p.textSecondary,
                        fontSize: ConfigUI.fontSizeLabel,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (isCodeStep) ...[
                    Text(
                      context.tr('codeSentHint', namedArgs: {'email': _email!}),
                      style: TextStyle(
                        color: p.textSecondary,
                        fontSize: ConfigUI.fontSizeLabel,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _codeController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: context.tr('verificationCodePlaceholder'),
                        counterText: '',
                        filled: true,
                        fillColor: p.cardBackground,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        TextButton(
                          onPressed: _loading ? null : _goBack,
                          child: Text(context.tr('emailChange'), style: TextStyle(color: p.textSecondary)),
                        ),
                        const Spacer(),
                        FilledButton(
                          onPressed: _loading ? null : _verifyCode,
                          child: _loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Text(context.tr('login')),
                        ),
                      ],
                    ),
                  ] else ...[
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      decoration: InputDecoration(
                        hintText: context.tr('emailPlaceholder'),
                        filled: true,
                        fillColor: p.cardBackground,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _loading ? null : _sendCode,
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(context.tr('getCode')),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      style: TextStyle(color: p.accent, fontSize: ConfigUI.fontSizeLabel),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
