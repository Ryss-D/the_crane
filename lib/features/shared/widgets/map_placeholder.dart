import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

/// Clearly-marked stand-in for the Google Map.
///
/// TODO(FND-6): replace with google_maps_flutter (customer: pickup/dropoff
/// pins + Places search; driver: own position + route) once Maps API keys
/// and native setup are in place.
class MapPlaceholder extends StatelessWidget {
  const MapPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_outlined, size: 40, color: scheme.outline),
            const SizedBox(height: 8),
            Text(
              l10n.mapPlaceholderBody,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.outline),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
