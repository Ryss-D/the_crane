// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'The Crane';

  @override
  String get signInTitle => 'Inicia sesión';

  @override
  String get signInSubtitle =>
      'Pide una grúa para tu moto o carro en Medellín.';

  @override
  String get signInPhoneButton => 'Continuar con teléfono';

  @override
  String get continueAsCustomer => 'Entrar como cliente';

  @override
  String get continueAsDriver => 'Entrar como conductor';

  @override
  String get customerHomeTitle => 'Pedir grúa';

  @override
  String get customerHomeBody => 'Aquí irá el mapa para pedir una grúa.';

  @override
  String get driverHomeTitle => 'Panel del conductor';

  @override
  String get driverHomeBody =>
      'Aquí irán tu disponibilidad y las ofertas de servicio.';
}
