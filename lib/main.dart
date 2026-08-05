import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';
import 'app/theme.dart';
import 'l10n/app_localizations.dart';

void main() {
  // TODO(FND-1): initialize Firebase here (WidgetsFlutterBinding +
  // Firebase.initializeApp with per-flavor options) once the Firebase
  // project is wired.
  runApp(const ProviderScope(child: TheCraneApp()));
}

class TheCraneApp extends ConsumerWidget {
  const TheCraneApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('es'),
      routerConfig: router,
    );
  }
}
