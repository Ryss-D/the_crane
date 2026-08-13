import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_crane/core/api/fake_vehicles_repository.dart';
import 'package:the_crane/core/models/saved_vehicle.dart';
import 'package:the_crane/features/customer/request/request_screen.dart';
import 'package:the_crane/features/customer/settings/saved_vehicles_screen.dart';
import 'package:the_crane/features/customer/settings/settings_screen.dart';
import 'package:the_crane/main.dart';

import '../../support/test_dependencies.dart';

/// Lets `listVehicles` be forced to fail, or to come back empty, so CUS-6's
/// error/retry and empty states are reachable without a real backend.
///
/// `rejectLoads` deliberately stays sticky (cleared explicitly by the test,
/// not consumed on first use like `RejectingOnceJobsRepository`,
/// `test/support/`): the `vehicles` route's `BlocProvider(create: ...
/// ..load())` fires more than once per navigation here (go_router builds
/// the destination page ahead of the transition settling), so a
/// single-shot flag risks being consumed by a load the assertions never
/// observe.
class _FlakyVehiclesRepository extends FakeVehiclesRepository {
  _FlakyVehiclesRepository({super.delay});

  bool rejectLoads = false;
  bool emptyList = false;

  @override
  Future<List<SavedVehicle>> listVehicles() async {
    if (rejectLoads) throw StateError('boom');
    if (emptyList) {
      await Future<void>.delayed(delay);
      return const [];
    }
    return super.listVehicles();
  }
}

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

  testWidgets('CUS-6: dismissing the delete confirmation keeps the vehicle',
      (tester) async {
    await pumpToSavedVehicles(tester);

    await tester.tap(find.byKey(const Key('deleteVehicleButton_veh-1')));
    await tester.pumpAndSettle();
    expect(find.text('¿Eliminar vehículo?'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('savedVehicleRow_veh-1')), findsOneWidget);
    expect(find.byKey(const Key('savedVehicleRow_veh-2')), findsOneWidget);
  });

  testWidgets('CUS-6: a failed load offers retry, which then succeeds',
      (tester) async {
    final vehicles = _FlakyVehiclesRepository(
      delay: const Duration(milliseconds: 10),
    )..rejectLoads = true;
    await tester.pumpWidget(
      TheCraneApp(dependencies: testDependencies(vehicles: vehicles)),
    );
    await tester.pumpAndSettle();
    await signIn(tester);
    await tester.tap(find.byKey(const Key('settingsNavButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('savedVehiclesMenuItem')));
    await tester.pumpAndSettle();

    expect(
      find.text('No pudimos cargar tus vehículos. Intenta de nuevo.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('savedVehicleRow_veh-1')), findsNothing);

    vehicles.rejectLoads = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('savedVehicleRow_veh-1')), findsOneWidget);
  });

  testWidgets('CUS-6: no saved vehicles shows the empty body', (tester) async {
    final vehicles = _FlakyVehiclesRepository(
      delay: const Duration(milliseconds: 10),
    )..emptyList = true;
    await tester.pumpWidget(
      TheCraneApp(dependencies: testDependencies(vehicles: vehicles)),
    );
    await tester.pumpAndSettle();
    await signIn(tester);
    await tester.tap(find.byKey(const Key('settingsNavButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('savedVehiclesMenuItem')));
    await tester.pumpAndSettle();

    expect(find.text('Aún no tienes vehículos guardados.'), findsOneWidget);
  });
}
