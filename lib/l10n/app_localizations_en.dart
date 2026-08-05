// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'The Crane';

  @override
  String get signInTitle => 'Sign in';

  @override
  String get signInSubtitle =>
      'Request a tow truck for your motorcycle or car in Medellín.';

  @override
  String get signInPhoneButton => 'Continue with phone';

  @override
  String get continueAsCustomer => 'Enter as customer';

  @override
  String get continueAsDriver => 'Enter as driver';

  @override
  String get customerHomeTitle => 'Request a tow';

  @override
  String get customerHomeBody =>
      'The map to request a tow truck will live here.';

  @override
  String get driverHomeTitle => 'Driver dashboard';

  @override
  String get driverHomeBody =>
      'Your availability and job offers will live here.';
}
