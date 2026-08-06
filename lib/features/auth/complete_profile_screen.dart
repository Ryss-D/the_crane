import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../l10n/app_localizations.dart';
import 'auth_cubit.dart';

/// AUTH-3: profile completion — shown once, only when the synced backend
/// profile has no name yet (phone auth alone gives the backend nothing to
/// go on). `AuthCubit.completeProfile` moves to `authenticated`, and
/// `routerRedirect` sends the user to their role's home shell.
class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _controller = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save(String name) async {
    setState(() => _saving = true);
    await context.read<AuthCubit>().completeProfile(name);
    // No `if (mounted)` guard needed for `setState` after this: a successful
    // completeProfile flips AuthCubit to `authenticated`, and the router
    // redirect navigates away, unmounting this screen — `mounted` is false
    // by the time we'd reach any code after the await in the failure-free
    // path, and we don't retry setState on failure here (kept minimal).
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.completeProfileTitle,
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.completeProfileSubtitle,
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextField(
                key: const Key('completeProfileNameField'),
                controller: _controller,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(labelText: l10n.completeProfileNameLabel),
              ),
              const SizedBox(height: 16),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _controller,
                builder: (context, value, _) {
                  return FilledButton(
                    key: const Key('completeProfileSaveButton'),
                    onPressed: _saving || value.text.trim().isEmpty
                        ? null
                        : () => _save(value.text.trim()),
                    child: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.completeProfileSaveButton),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
