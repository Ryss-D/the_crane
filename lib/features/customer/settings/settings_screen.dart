import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../l10n/app_localizations.dart';

/// Reachable from the customer home app bar. AUTH-5's "become a driver",
/// CUS-6's saved-vehicles, and FLT-1's "become a fleet owner" entry points.
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
              key: const Key('savedVehiclesMenuItem'),
              leading: const Icon(Icons.directions_car_outlined),
              title: Text(l10n.savedVehiclesMenuItem),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoute.customerVehicles),
            ),
            ListTile(
              key: const Key('becomeDriverMenuItem'),
              leading: const Icon(Icons.local_shipping_outlined),
              title: Text(l10n.becomeDriverMenuItem),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoute.customerBecomeDriver),
            ),
            ListTile(
              key: const Key('becomeFleetOwnerMenuItem'),
              leading: const Icon(Icons.warehouse_outlined),
              title: Text(l10n.becomeFleetOwnerMenuItem),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoute.customerBecomeFleetOwner),
            ),
          ],
        ),
      ),
    );
  }
}
