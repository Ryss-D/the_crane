import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_crane/features/customer/request/request_screen.dart';
import 'package:the_crane/features/customer/settings/saved_vehicles_screen.dart';
import 'package:the_crane/features/customer/settings/settings_screen.dart';
import 'package:the_crane/main.dart';

import '../../support/test_dependencies.dart';

void main() {
  Future<void> pumpToSavedVehicles(WidgetTester tester) async {
    await tester.pumpWidget(TheCraneApp(dependencies: testDependencies()));
    await tester.pumpAndSettle();
    await signIn(tester);
    expect(find.byType(RequestScreen), findsOneWidget);

    await tester.tap(find.byKey(const Key('settingsNavButton')));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);

    await tester.tap(find.byKey(const Key('savedVehiclesMenuItem')));
    await tester.pumpAndSettle();
    expect(find.byType(SavedVehiclesScreen), findsOneWidget);
  }

  testWidgets('CUS-6: lists the two seeded vehicles', (tester) async {
    await pumpToSavedVehicles(tester);

    expect(find.byKey(const Key('savedVehicleRow_veh-1')), findsOneWidget);
    expect(find.byKey(const Key('savedVehicleRow_veh-2')), findsOneWidget);
    expect(find.textContaining('ABC123'), findsOneWidget);
  });

  testWidgets('CUS-6: adds a new vehicle', (tester) async {
    await pumpToSavedVehicles(tester);

    await tester.tap(find.byKey(const Key('addVehicleButton')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('vehicleFormPlateField')),
      'NEW999',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('vehicleFormSaveButton')));
    await tester.pump(const Duration(milliseconds: 200)); // save delay
    await tester.pumpAndSettle();

    expect(find.textContaining('NEW999'), findsOneWidget);
  });

  testWidgets('CUS-6: edits an existing vehicle', (tester) async {
    await pumpToSavedVehicles(tester);

    await tester.tap(find.byKey(const Key('editVehicleButton_veh-1')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('vehicleFormPlateField')),
      'EDITED1',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('vehicleFormSaveButton')));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    expect(find.textContaining('EDITED1'), findsOneWidget);
    expect(find.textContaining('ABC123'), findsNothing);
  });

  testWidgets('CUS-6: deletes a vehicle after confirmation', (tester) async {
    await pumpToSavedVehicles(tester);

    await tester.tap(find.byKey(const Key('deleteVehicleButton_veh-1')));
    await tester.pumpAndSettle();
    // Confirmation dialog.
    expect(find.text('¿Eliminar vehículo?'), findsOneWidget);

    await tester.tap(find.text('Eliminar'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('savedVehicleRow_veh-1')), findsNothing);
    expect(find.byKey(const Key('savedVehicleRow_veh-2')), findsOneWidget);
  });
}
