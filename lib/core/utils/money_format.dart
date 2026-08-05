import 'package:intl/intl.dart';

/// Colombian-peso amount formatting: `85000` → `$ 85.000`.
///
/// COP has no cents in practice, so amounts are integer pesos everywhere.
final NumberFormat _cop = NumberFormat.currency(
  locale: 'es_CO',
  symbol: r'$',
  decimalDigits: 0,
  // es_CO CLDR places the symbol after the amount ("85.000 $"); Colombian
  // apps conventionally show "$ 85.000", so pin symbol-first while keeping
  // the locale's dot grouping.
  customPattern: '¤ #,##0',
);

/// Formats an integer COP amount for display (es_CO grouping).
String formatCop(int amount) => _cop.format(amount);

/// Formats a distance in kilometers with one decimal (es_CO separators),
/// e.g. `8.4` → `8,4`.
String formatKm(double km) => NumberFormat('#,##0.0', 'es_CO').format(km);
