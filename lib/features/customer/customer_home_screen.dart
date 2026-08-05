import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// Placeholder customer shell.
///
/// TODO(FND-6): the request-a-tow map (google_maps_flutter) plugs in here
/// once Maps keys and native setup are done.
class CustomerHomeScreen extends StatelessWidget {
  const CustomerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.customerHomeTitle)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n.customerHomeBody,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
