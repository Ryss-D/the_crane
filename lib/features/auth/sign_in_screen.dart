import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../l10n/app_localizations.dart';

/// Placeholder sign-in screen.
///
/// TODO(AUTH-3): replace with the real phone-OTP flow (firebase_auth,
/// depends on FND-1 native wiring). The role buttons below are a dev-only
/// role switch so both shells are reachable before auth exists.
class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

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
              FilledButton.icon(
                icon: const Icon(Icons.phone),
                // TODO(AUTH-3): launch the phone OTP flow.
                onPressed: null,
                label: Text(l10n.signInPhoneButton),
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () => context.go(AppRoute.customerHome),
                child: Text(l10n.continueAsCustomer),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => context.go(AppRoute.driverHome),
                child: Text(l10n.continueAsDriver),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
