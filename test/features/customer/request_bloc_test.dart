import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_crane/core/api/fake_jobs_repository.dart';
import 'package:the_crane/core/models/job.dart';
import 'package:the_crane/features/customer/request/request_bloc.dart';
import 'package:the_crane/features/customer/request/request_state.dart';

FakeJobsRepository instantFakeJobs({
  Duration matchingDelay = const Duration(milliseconds: 30),
  FakeMatchingOutcome outcome = FakeMatchingOutcome.assigned,
}) {
  return FakeJobsRepository(
    quoteDelay: Duration.zero,
    createDelay: Duration.zero,
    actionDelay: Duration.zero,
    matchingDelay: matchingDelay,
    matchingOutcome: outcome,
  );
}

Future<void> tick([int ms = 10]) =>
    Future<void>.delayed(Duration(milliseconds: ms));

void main() {
  group('RequestBloc quote flow', () {
    blocTest<RequestBloc, RequestState>(
      'no quote until both addresses are set',
      build: () => RequestBloc(jobsRepository: instantFakeJobs()),
      act: (bloc) => bloc.add(const RequestPickupChanged('Calle 10 #43E-31')),
      wait: const Duration(milliseconds: 20),
      verify: (bloc) {
        expect(bloc.state.pickupAddress, 'Calle 10 #43E-31');
        expect(bloc.state.quote, isNull);
        expect(bloc.state.isQuoting, isFalse);
        expect(bloc.state.canConfirm, isFalse);
      },
    );

    blocTest<RequestBloc, RequestState>(
      'entering both addresses fetches a quote',
      build: () => RequestBloc(jobsRepository: instantFakeJobs()),
      act: (bloc) => bloc
        ..add(const RequestPickupChanged('Calle 10 #43E-31'))
        ..add(const RequestDropoffChanged('Cra. 48, Envigado')),
      wait: const Duration(milliseconds: 50),
      verify: (bloc) {
        final state = bloc.state;
        expect(state.quote, isNotNull);
        expect(state.isQuoting, isFalse);
        expect(state.quoteFailed, isFalse);
        expect(state.quote!.price, greaterThan(0));
        expect(state.quote!.vehicleType, VehicleType.car);
        expect(state.canConfirm, isTrue);
      },
    );

    blocTest<RequestBloc, RequestState>(
      'changing the vehicle type re-quotes',
      build: () => RequestBloc(jobsRepository: instantFakeJobs()),
      act: (bloc) async {
        bloc
          ..add(const RequestPickupChanged('Calle 10 #43E-31'))
          ..add(const RequestDropoffChanged('Cra. 48, Envigado'));
        await tick(30);
        bloc.add(const RequestVehicleTypeChanged(VehicleType.moto));
      },
      wait: const Duration(milliseconds: 50),
      verify: (bloc) {
        expect(bloc.state.quote!.vehicleType, VehicleType.moto);
      },
    );
  });

  group('RequestBloc matching flow', () {
    test('confirm → matching → assigned with driver card data', () async {
      final bloc = RequestBloc(jobsRepository: instantFakeJobs());
      bloc
        ..add(const RequestPickupChanged('Calle 10 #43E-31'))
        ..add(const RequestDropoffChanged('Cra. 48, Envigado'));
      await tick(30);
      expect(bloc.state.quote, isNotNull);

      bloc.add(const RequestConfirmed());
      await tick();
      expect(bloc.state.activeJob, isNotNull);
      expect(bloc.state.activeJob!.status, JobStatus.matching);

      await tick(60); // matchingDelay elapses → assigned via watch stream.
      final job = bloc.state.activeJob!;
      expect(job.status, JobStatus.assigned);
      expect(job.driver, isNotNull);
      expect(job.driver!.name, isNotEmpty);
      expect(job.driver!.truckPlate, isNotEmpty);

      await bloc.close();
    });

    test('no-drivers outcome, then retry succeeds', () async {
      final repo = instantFakeJobs(outcome: FakeMatchingOutcome.noDrivers);
      final bloc = RequestBloc(jobsRepository: repo);
      bloc
        ..add(const RequestPickupChanged('Calle 10 #43E-31'))
        ..add(const RequestDropoffChanged('Cra. 48, Envigado'));
      await tick(30);
      bloc.add(const RequestConfirmed());
      await tick(60);
      expect(bloc.state.activeJob!.status, JobStatus.noDrivers);

      // A driver comes online; retry re-requests with the same quote.
      repo.matchingOutcome = FakeMatchingOutcome.assigned;
      bloc.add(const RequestMatchingRetried());
      await tick();
      expect(bloc.state.activeJob!.status, JobStatus.matching);
      await tick(60);
      expect(bloc.state.activeJob!.status, JobStatus.assigned);

      await bloc.close();
    });

    test('abandoning matching clears the tracked job', () async {
      final bloc = RequestBloc(jobsRepository: instantFakeJobs());
      bloc
        ..add(const RequestPickupChanged('Calle 10 #43E-31'))
        ..add(const RequestDropoffChanged('Cra. 48, Envigado'));
      await tick(30);
      bloc.add(const RequestConfirmed());
      await tick();
      expect(bloc.state.activeJob, isNotNull);

      bloc.add(const RequestMatchingAbandoned());
      await tick();
      expect(bloc.state.activeJob, isNull);

      await bloc.close();
    });
  });
}
