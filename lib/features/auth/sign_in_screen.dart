import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../l10n/app_localizations.dart';
import 'auth_cubit.dart';
import 'auth_state.dart';

/// Colombia default — the rest of the app (Places bias, currency) already
/// assumes es-CO, so a bare local number is treated as +57. Typing a
/// leading "+" opts out for anyone signing in from elsewhere.
String _toE164(String input) {
  final trimmed = input.trim();
  if (trimmed.startsWith('+')) {
    return '+${trimmed.replaceAll(RegExp(r'[^\d]'), '')}';
  }
  return '+57${trimmed.replaceAll(RegExp(r'\D'), '')}';
}

/// AUTH-3: phone entry — the first step of sign-in. `AuthCubit.sendCode`
/// moves to [AuthPhase.codeSent], which `routerRedirect` turns into a push
/// to the OTP screen.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: BlocBuilder<AuthCubit, AuthState>(
            builder: (context, state) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.car_repair,
                    size: 72,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.signInTitle,
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.signInSubtitle,
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    key: const Key('signInPhoneField'),
                    controller: _controller,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: l10n.signInPhoneLabel,
                      hintText: l10n.signInPhoneHint,
                      prefixText: '+57 ',
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (state.sendCodeFailed) ...[
                    Text(
                      l10n.signInSendCodeError,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                  ],
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _controller,
                    builder: (context, value, _) {
                      return FilledButton.icon(
                        key: const Key('sendCodeButton'),
                        icon: const Icon(Icons.phone),
                        onPressed: state.isSendingCode || value.text.trim().isEmpty
                            ? null
                            : () => context.read<AuthCubit>().sendCode(_toE164(value.text)),
                        label: state.isSendingCode
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(l10n.signInPhoneButton),
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
