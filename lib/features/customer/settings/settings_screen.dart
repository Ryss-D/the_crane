import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../l10n/app_localizations.dart';

/// Reachable from the customer home app bar. Currently a thin menu: AUTH-5's
/// "become a driver" entry point (CUS-6's saved-vehicles entry joins it
/// alongside once that's built).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: SafeArea(
        child: ListView(
          children: [
            ListTile(
              key: const Key('becomeDriverMenuItem'),
              leading: const Icon(Icons.local_shipping_outlined),
              title: Text(l10n.becomeDriverMenuItem),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoute.customerBecomeDriver),
            ),
          ],
        ),
      ),
    );
  }
}
