import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// Placeholder driver shell (availability toggle + offer sheet come later).
class DriverHomeScreen extends StatelessWidget {
  const DriverHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.driverHomeTitle)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n.driverHomeBody,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
