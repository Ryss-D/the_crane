import 'package:flutter_test/flutter_test.dart';
import 'package:the_crane/core/utils/money_format.dart';

/// es_CO formatting uses a non-breaking space between symbol and amount;
/// normalize for readable assertions.
String norm(String s) => s.replaceAll(' ', ' ');

void main() {
  group('formatCop', () {
    test('formats COP with es_CO grouping and no decimals', () {
      expect(norm(formatCop(85000)), r'$ 85.000');
      expect(norm(formatCop(1234567)), r'$ 1.234.567');
      expect(norm(formatCop(0)), r'$ 0');
    });
  });

  group('formatKm', () {
    test('one decimal with es_CO separator', () {
      expect(formatKm(8.4), '8,4');
      expect(formatKm(12.0), '12,0');
      expect(formatKm(1234.56), '1.234,6');
    });
  });
}
