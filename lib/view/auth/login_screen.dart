// login_screen.dart
// 이메일 입력 → 코드 발송 → 코드 입력 → 로그인

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:syncflow/service/api_client.dart';
import 'package:syncflow/theme/app_theme_colors.dart';
import 'package:syncflow/util/config_ui.dart';
import 'package:syncflow/vm/session_notifier.dart';
import 'package:syncflow/widget/keyboard_dismiss_scroll_view.dart';

/// 로그인 화면
/// Step 1: 이메일 입력 → 코드 발송
/// Step 2: 코드 입력 → 로그인
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  String? _email; // 코드 발송 후 저장
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        _error = '이메일을 입력하세요.';
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
    } catch (_) {
      setState(() {
        _loading = false;
        _error = '인증 코드 발송에 실패했습니다.';
      });
    }
  }

  Future<void> _verifyCode() async {
    final email = _email ?? _emailController.text.trim();
    final code = _codeController.text.trim();
    if (email.isEmpty || code.isEmpty) {
      setState(() {
        _error = '이메일과 인증 코드를 입력하세요.';
      });
      return;
    }
    if (code.length != 6) {
      setState(() {
        _error = '인증 코드는 6자리 숫자입니다.';
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
      // 세션 저장 후 main.dart의 sessionNotifierProvider watch로 MainScaffold로 전환됨
    } on ApiException catch (e) {
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (_) {
      setState(() {
        _loading = false;
        _error = '인증에 실패했습니다.';
      });
    }
  }

  void _goBack() {
    setState(() {
      _email = null;
      _error = null;
      _codeController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.appTheme;
    final isCodeStep = _email != null;

    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        child: KeyboardDismissScrollView(
          keyboardPadding: false,
          padding: const EdgeInsets.symmetric(horizontal: ConfigUI.screenPaddingH),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'SyncFlow',
                    style: TextStyle(
                      color: p.textPrimary,
                      fontSize: ConfigUI.fontSizeTitle,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '소규모 팀을 위한 협업 칸반',
                    style: TextStyle(
                      color: p.textSecondary,
                      fontSize: ConfigUI.fontSizeBody,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  if (isCodeStep) ...[
                    Text(
                      '$_email 로 발송된 6자리 코드를 입력하세요.',
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
                        hintText: '000000',
                        counterText: '',
                        filled: true,
                        fillColor: p.cardBackground,
                        border: OutlineInputBorder(
                          borderRadius: ConfigUI.inputRadius,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        TextButton(
                          onPressed: _loading ? null : _goBack,
                          child: Text('이메일 변경', style: TextStyle(color: p.textSecondary)),
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
                              : const Text('로그인'),
                        ),
                      ],
                    ),
                  ] else ...[
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      decoration: InputDecoration(
                        hintText: '이메일 주소',
                        filled: true,
                        fillColor: p.cardBackground,
                        border: OutlineInputBorder(
                          borderRadius: ConfigUI.inputRadius,
                        ),
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
                          : const Text('인증 코드 받기'),
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
