import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../l10n/app_localizations.dart';
import 'auth_cubit.dart';
import 'auth_state.dart';

/// AUTH-3: OTP entry — the second step of sign-in. On success `AuthCubit`
/// moves through `syncing` into `authenticated`/`needsProfile`, and
/// `routerRedirect` takes it from there.
class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
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
              final isSyncing = state.phase == AuthPhase.syncing;
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.otpTitle,
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  if (state.phoneNumber != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      l10n.otpSentTo(state.phoneNumber!),
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 24),
                  TextField(
                    key: const Key('otpCodeField'),
                    controller: _controller,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: l10n.otpLabel,
                      hintText: l10n.otpHint,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (state.confirmCodeFailed) ...[
                    Text(
                      l10n.otpConfirmError,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                  ],
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _controller,
                    builder: (context, value, _) {
                      final busy = state.isConfirmingCode || isSyncing;
                      return FilledButton(
                        key: const Key('confirmCodeButton'),
                        onPressed: busy || value.text.trim().isEmpty
                            ? null
                            : () => context.read<AuthCubit>().confirmCode(value.text.trim()),
                        child: busy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(l10n.otpConfirmButton),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => context.read<AuthCubit>().signOut(),
                    child: Text(l10n.otpChangeNumber),
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
