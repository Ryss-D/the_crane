import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_crane/features/auth/sign_in_screen.dart';
import 'package:the_crane/features/customer/customer_home_screen.dart';
import 'package:the_crane/main.dart';

void main() {
  testWidgets('app builds and shows the auth placeholder', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: TheCraneApp()));
    await tester.pumpAndSettle();

    expect(find.byType(SignInScreen), findsOneWidget);
    // Primary locale is es.
    expect(find.text('Inicia sesión'), findsOneWidget);
    expect(find.text('Entrar como cliente'), findsOneWidget);
  });

  testWidgets('role switch stub navigates to the customer shell',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: TheCraneApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Entrar como cliente'));
    await tester.pumpAndSettle();

    expect(find.byType(CustomerHomeScreen), findsOneWidget);
    expect(find.text('Pedir grúa'), findsOneWidget);
  });
}
