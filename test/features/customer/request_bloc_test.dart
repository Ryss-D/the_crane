import 'dart:convert';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_crane/core/api/fake_jobs_repository.dart';
import 'package:the_crane/core/models/job.dart';
import 'package:the_crane/core/models/lat_lng.dart';
import 'package:the_crane/core/models/place_prediction.dart';
import 'package:the_crane/core/models/quote.dart';
import 'package:the_crane/core/ws/crane_socket.dart';
import 'package:the_crane/features/customer/request/request_bloc.dart';
import 'package:the_crane/features/customer/request/request_state.dart';

import '../../support/fake_web_socket_channel.dart';
import '../../support/in_memory_active_job_store.dart';

/// FND-6 test double: records the coordinates the bloc actually requested a
/// quote for, so tests can tell a real Places coordinate apart from
/// `fakeGeocode`'s hashed one without reverse-engineering the hash.
class CapturingQuoteJobsRepository extends FakeJobsRepository {
  CapturingQuoteJobsRepository()
      : super(quoteDelay: Duration.zero, createDelay: Duration.zero, actionDelay: Duration.zero);

  LatLng? lastPickup;
  LatLng? lastDropoff;

  @override
  Future<Quote> requestQuote({
    required LatLng pickup,
    required LatLng dropoff,
    required VehicleType vehicleType,
  }) {
    lastPickup = pickup;
    lastDropoff = dropoff;
    return super.requestQuote(pickup: pickup, dropoff: dropoff, vehicleType: vehicleType);
  }
}

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

/// CUS-2 test double: overrides the seeded 10-minute `expiresAt` with a
/// short, injectable [ttl] so a stale-quote re-fetch test doesn't need to
/// wait out the real default. Also counts [requestQuote] calls so a test
/// can assert a re-fetch did (or didn't) happen without depending on
/// `quoteId` string shape.
class ShortTtlQuoteJobsRepository extends FakeJobsRepository {
  ShortTtlQuoteJobsRepository({
    required this.ttl,
    super.matchingDelay = const Duration(milliseconds: 30),
  }) : super(
          quoteDelay: Duration.zero,
          createDelay: Duration.zero,
          actionDelay: Duration.zero,
        );

  final Duration ttl;
  int quoteCalls = 0;

  @override
  Future<Quote> requestQuote({
    required LatLng pickup,
    required LatLng dropoff,
    required VehicleType vehicleType,
  }) async {
    quoteCalls++;
    final quote = await super.requestQuote(
      pickup: pickup,
      dropoff: dropoff,
      vehicleType: vehicleType,
    );
    return quote.copyWith(expiresAt: DateTime.now().add(ttl));
  }
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

  group('RequestBloc CUS-2 stale-quote re-fetch', () {
    test('auto re-fetches once the quote passes its expiresAt', () async {
      final repo = ShortTtlQuoteJobsRepository(ttl: const Duration(milliseconds: 30));
      final bloc = RequestBloc(jobsRepository: repo);
      bloc
        ..add(const RequestPickupChanged('Calle 10 #43E-31'))
        ..add(const RequestDropoffChanged('Cra. 48, Envigado'));
      await tick(20);
      final firstQuoteId = bloc.state.quote!.quoteId;

      // Past the short TTL, with no other action from the customer.
      await tick(60);

      expect(bloc.state.quote, isNotNull);
      expect(bloc.state.quote!.quoteId, isNot(firstQuoteId));
      expect(bloc.state.quoteFailed, isFalse);

      await bloc.close();
    });

    test('does not re-fetch once the customer has already confirmed',
        () async {
      final repo = ShortTtlQuoteJobsRepository(
        ttl: const Duration(milliseconds: 30),
        matchingDelay: const Duration(seconds: 5),
      );
      final bloc = RequestBloc(jobsRepository: repo);
      bloc
        ..add(const RequestPickupChanged('Calle 10 #43E-31'))
        ..add(const RequestDropoffChanged('Cra. 48, Envigado'));
      await tick(20);
      bloc.add(const RequestConfirmed());
      await tick(20);
      final quoteCallsAfterConfirm = repo.quoteCalls;
      expect(bloc.state.activeJob, isNotNull);

      // Past the TTL, but the bloc has moved on to matching -- no re-fetch.
      await tick(60);
      expect(repo.quoteCalls, quoteCallsAfterConfirm);

      await bloc.close();
    });
  });

  group('RequestBloc CUS-5 delivery confirmation', () {
    Future<RequestBloc> deliveredBloc() async {
      final repo = instantFakeJobs();
      final bloc = RequestBloc(jobsRepository: repo);
      bloc
        ..add(const RequestPickupChanged('Calle 10 #43E-31'))
        ..add(const RequestDropoffChanged('Cra. 48, Envigado'));
      await tick(30);
      bloc.add(const RequestConfirmed());
      await tick(60); // matching resolves -> assigned
      final jobId = bloc.state.activeJob!.id;
      var job = bloc.state.activeJob!;
      while (job.status != JobStatus.delivered) {
        job = await repo.updateJobStatus(jobId, job.status.nextDriverStatus!);
      }
      await tick(); // watch stream picks up the driver-side advances
      expect(bloc.state.activeJob!.status, JobStatus.delivered);
      return bloc;
    }

    test('confirming delivery completes the job', () async {
      final bloc = await deliveredBloc();

      bloc.add(const RequestDeliveryConfirmed());
      await tick();

      expect(bloc.state.activeJob!.status, JobStatus.completed);
      expect(bloc.state.activeJob!.completedAt, isNotNull);
      expect(bloc.state.isConfirmingDelivery, isFalse);
      expect(bloc.state.confirmDeliveryFailed, isFalse);

      await bloc.close();
    });

    test('is a no-op when the job is not yet delivered', () async {
      final repo = instantFakeJobs();
      final bloc = RequestBloc(jobsRepository: repo);
      bloc
        ..add(const RequestPickupChanged('Calle 10 #43E-31'))
        ..add(const RequestDropoffChanged('Cra. 48, Envigado'));
      await tick(30);
      bloc.add(const RequestConfirmed());
      await tick(60); // assigned, not delivered
      expect(bloc.state.activeJob!.status, JobStatus.assigned);

      bloc.add(const RequestDeliveryConfirmed());
      await tick();
      expect(bloc.state.activeJob!.status, JobStatus.assigned);
      expect(bloc.state.isConfirmingDelivery, isFalse);

      await bloc.close();
    });
  });

  group('RequestBloc PAY-4 digital-fare confirmation', () {
    Future<(RequestBloc, FakeJobsRepository)> deliveredBlocWithRepo() async {
      final repo = instantFakeJobs();
      final bloc = RequestBloc(jobsRepository: repo);
      bloc
        ..add(const RequestPickupChanged('Calle 10 #43E-31'))
        ..add(const RequestDropoffChanged('Cra. 48, Envigado'));
      await tick(30);
      bloc.add(const RequestConfirmed());
      await tick(60); // matching resolves -> assigned
      final jobId = bloc.state.activeJob!.id;
      var job = bloc.state.activeJob!;
      while (job.status != JobStatus.delivered) {
        job = await repo.updateJobStatus(jobId, job.status.nextDriverStatus!);
      }
      await tick();
      expect(bloc.state.activeJob!.status, JobStatus.delivered);
      return (bloc, repo);
    }

    test('a PSE confirmation completes the job and surfaces the redirect URL',
        () async {
      final (bloc, _) = await deliveredBlocWithRepo();

      bloc.add(const RequestDeliveryConfirmed(paymentMethod: 'pse'));
      await tick();

      expect(bloc.state.activeJob!.status, JobStatus.completed);
      expect(bloc.state.activeJob!.asyncPaymentUrl, isNotNull);
      // Digital fare: the ledger entry (and so the real commission) is
      // deferred to the (here, never-arriving) webhook -- unlike a cash
      // confirmation, this must stay null.
      expect(bloc.state.activeJob!.driverCommission, isNull);
      expect(bloc.state.confirmDeliveryFailed, isFalse);

      await bloc.close();
    });

    test('a Nequi confirmation completes the job with no redirect URL',
        () async {
      final (bloc, _) = await deliveredBlocWithRepo();

      bloc.add(const RequestDeliveryConfirmed(paymentMethod: 'nequi'));
      await tick();

      expect(bloc.state.activeJob!.status, JobStatus.completed);
      expect(bloc.state.activeJob!.asyncPaymentUrl, isNull);

      await bloc.close();
    });

    test(
        'a rejected digital confirmation (flag off server-side) surfaces the '
        'backend detail and leaves the job delivered', () async {
      final (bloc, repo) = await deliveredBlocWithRepo();
      repo.digitalFaresEnabled = false;

      bloc.add(const RequestDeliveryConfirmed(paymentMethod: 'card'));
      await tick();

      expect(bloc.state.activeJob!.status, JobStatus.delivered);
      expect(bloc.state.confirmDeliveryFailed, isTrue);
      expect(bloc.state.confirmDeliveryErrorMessage, isNotNull);

      await bloc.close();
    });
  });

  group('RequestBloc CUS-4 job rehydration', () {
    const pickup = LatLng(lat: 6.2442, lng: -75.5812);
    const dropoff = LatLng(lat: 6.2, lng: -75.58);

    Future<Job> createJobDirectly(FakeJobsRepository repo) async {
      final quote = await repo.requestQuote(
        pickup: pickup,
        dropoff: dropoff,
        vehicleType: VehicleType.car,
      );
      return repo.createJob(
        quoteId: quote.quoteId,
        vehicleType: VehicleType.car,
        pickup: pickup,
        pickupAddress: 'Calle 10 #43E-31',
        dropoff: dropoff,
        dropoffAddress: 'Cra. 48, Envigado',
      );
    }

    test('resumes a persisted non-terminal job on construction', () async {
      final repo = instantFakeJobs();
      final job = await createJobDirectly(repo); // status: matching
      final store = InMemoryActiveJobStore();
      await store.write(job.id);

      final bloc = RequestBloc(jobsRepository: repo, activeJobStore: store);
      await tick();

      expect(bloc.state.activeJob?.id, job.id);
      expect(bloc.state.activeJob?.status, JobStatus.matching);

      // Rehydration also resumes watching -- the assignment that follows
      // still reaches this bloc, same as if it had created the job itself.
      await tick(60);
      expect(bloc.state.activeJob?.status, JobStatus.assigned);

      await bloc.close();
    });

    test('does not resume a terminal job, and clears the stale id', () async {
      final repo = instantFakeJobs();
      final created = await createJobDirectly(repo);
      await tick(60); // -> assigned
      var job = await repo.getJob(created.id);
      while (job.status != JobStatus.delivered) {
        job = await repo.updateJobStatus(job.id, job.status.nextDriverStatus!);
      }
      job = await repo.confirmDelivery(job.id); // -> completed
      final store = InMemoryActiveJobStore();
      await store.write(job.id);

      final bloc = RequestBloc(jobsRepository: repo, activeJobStore: store);
      await tick();

      expect(bloc.state.activeJob, isNull);
      expect(await store.read(), isNull);

      await bloc.close();
    });

    test('does not resume, and clears the id, when the job no longer exists',
        () async {
      final store = InMemoryActiveJobStore();
      await store.write('does-not-exist');

      final bloc = RequestBloc(
        jobsRepository: instantFakeJobs(),
        activeJobStore: store,
      );
      await tick();

      expect(bloc.state.activeJob, isNull);
      expect(await store.read(), isNull);

      await bloc.close();
    });

    test(
        'persists the active job id once matching starts, and clears it '
        'once abandoned', () async {
      final store = InMemoryActiveJobStore();
      final bloc = RequestBloc(
        jobsRepository: instantFakeJobs(),
        activeJobStore: store,
      );
      bloc
        ..add(const RequestPickupChanged('Calle 10 #43E-31'))
        ..add(const RequestDropoffChanged('Cra. 48, Envigado'));
      await tick(30);
      bloc.add(const RequestConfirmed());
      await tick();
      final jobId = bloc.state.activeJob!.id;
      expect(await store.read(), jobId);

      bloc.add(const RequestMatchingAbandoned());
      await tick();
      expect(await store.read(), isNull);

      await bloc.close();
    });

    test('clears the persisted id once the job completes', () async {
      final store = InMemoryActiveJobStore();
      final repo = instantFakeJobs();
      final bloc = RequestBloc(jobsRepository: repo, activeJobStore: store);
      bloc
        ..add(const RequestPickupChanged('Calle 10 #43E-31'))
        ..add(const RequestDropoffChanged('Cra. 48, Envigado'));
      await tick(30);
      bloc.add(const RequestConfirmed());
      await tick(60); // -> assigned
      var job = bloc.state.activeJob!;
      final jobId = job.id;
      while (job.status != JobStatus.delivered) {
        job = await repo.updateJobStatus(jobId, job.status.nextDriverStatus!);
      }
      await tick();
      expect(await store.read(), jobId); // still resumable while delivered

      bloc.add(const RequestDeliveryConfirmed());
      await tick();
      expect(bloc.state.activeJob!.status, JobStatus.completed);
      expect(await store.read(), isNull);

      await bloc.close();
    });
  });

  group('RequestBloc FND-6 real Places coordinates', () {
    const pickupDetails = PlaceDetails(
      lat: 6.21,
      lng: -75.58,
      formattedAddress: 'El Poblado, Medellín, Antioquia',
    );

    test('a Places selection quotes against the real coordinate, not fakeGeocode',
        () async {
      final repo = CapturingQuoteJobsRepository();
      final bloc = RequestBloc(jobsRepository: repo);
      bloc
        ..add(const RequestDropoffChanged('Cra. 48, Envigado'))
        ..add(const RequestPickupLocationSelected(pickupDetails));
      await tick(20);

      expect(bloc.state.pickupAddress, pickupDetails.formattedAddress);
      expect(bloc.state.pickupLatLng, const LatLng(lat: 6.21, lng: -75.58));
      expect(repo.lastPickup, const LatLng(lat: 6.21, lng: -75.58));
      // Dropoff was manually typed -- still the fakeGeocode fallback.
      expect(repo.lastDropoff, fakeGeocode('Cra. 48, Envigado'));

      await bloc.close();
    });

    test('typing over a selected pickup clears the real coordinate, '
        'falling back to fakeGeocode again', () async {
      final repo = CapturingQuoteJobsRepository();
      final bloc = RequestBloc(jobsRepository: repo);
      bloc
        ..add(const RequestDropoffChanged('Cra. 48, Envigado'))
        ..add(const RequestPickupLocationSelected(pickupDetails));
      await tick(20);
      expect(bloc.state.pickupLatLng, isNotNull);

      bloc.add(const RequestPickupChanged('Something typed by hand'));
      await tick(20);

      expect(bloc.state.pickupLatLng, isNull);
      expect(bloc.state.pickupAddress, 'Something typed by hand');
      expect(repo.lastPickup, fakeGeocode('Something typed by hand'));

      await bloc.close();
    });

    test('a job is created with the real selected coordinate', () async {
      final repo = CapturingQuoteJobsRepository();
      final bloc = RequestBloc(jobsRepository: repo);
      bloc
        ..add(const RequestDropoffChanged('Cra. 48, Envigado'))
        ..add(const RequestPickupLocationSelected(pickupDetails));
      await tick(20);

      bloc.add(const RequestConfirmed());
      await tick();

      expect(bloc.state.activeJob, isNotNull);
      expect(bloc.state.activeJob!.pickup, const LatLng(lat: 6.21, lng: -75.58));

      await bloc.close();
    });
  });

  group('RequestBloc FND-6 pin-drag', () {
    test('dragging the pickup pin sets a real coordinate and a plain '
        'coordinate address (no reverse geocoding available)', () async {
      final repo = CapturingQuoteJobsRepository();
      final bloc = RequestBloc(jobsRepository: repo);
      bloc
        ..add(const RequestDropoffChanged('Cra. 48, Envigado'))
        ..add(const RequestPickupPinMoved(LatLng(lat: 6.3, lng: -75.6)));
      await tick(20);

      expect(bloc.state.pickupLatLng, const LatLng(lat: 6.3, lng: -75.6));
      expect(bloc.state.pickupAddress, '6.30000, -75.60000');
      expect(repo.lastPickup, const LatLng(lat: 6.3, lng: -75.6));

      await bloc.close();
    });

    test('dragging again after a Places selection overrides its coordinate',
        () async {
      final repo = CapturingQuoteJobsRepository();
      final bloc = RequestBloc(jobsRepository: repo);
      bloc
        ..add(const RequestDropoffChanged('Cra. 48, Envigado'))
        ..add(const RequestPickupLocationSelected(
          PlaceDetails(lat: 6.21, lng: -75.58, formattedAddress: 'El Poblado'),
        ));
      await tick(20);

      bloc.add(const RequestPickupPinMoved(LatLng(lat: 6.22, lng: -75.59)));
      await tick(20);

      expect(bloc.state.pickupLatLng, const LatLng(lat: 6.22, lng: -75.59));
      expect(bloc.state.pickupAddress, '6.22000, -75.59000');

      await bloc.close();
    });
  });

  group('RequestBloc FND-6/CUS-4 live driver position', () {
    Future<(RequestBloc, FakeWebSocketChannel, String jobId)> assignedBlocWithSocket() async {
      final channel = FakeWebSocketChannel();
      final socket = CraneSocket(channelFactory: (_) => channel);
      socket.connect();
      await Future<void>.delayed(const Duration(milliseconds: 5)); // fake ready

      final repo = instantFakeJobs();
      final bloc = RequestBloc(jobsRepository: repo, socket: socket);
      bloc
        ..add(const RequestPickupChanged('Calle 10 #43E-31'))
        ..add(const RequestDropoffChanged('Cra. 48, Envigado'));
      await tick(30);
      bloc.add(const RequestConfirmed());
      await tick();
      final jobId = bloc.state.activeJob!.id;
      return (bloc, channel, jobId);
    }

    test('relays a driver_location push for the active job', () async {
      final (bloc, channel, jobId) = await assignedBlocWithSocket();
      expect(bloc.state.driverPosition, isNull);

      channel.addServerMessage(jsonEncode({
        'type': 'driver_location',
        'job_id': jobId,
        'lat': 6.25,
        'lng': -75.57,
      }));
      await tick();

      expect(bloc.state.driverPosition, const LatLng(lat: 6.25, lng: -75.57));

      await bloc.close();
    });

    test('ignores a driver_location push for a different job', () async {
      final (bloc, channel, _) = await assignedBlocWithSocket();

      channel.addServerMessage(jsonEncode({
        'type': 'driver_location',
        'job_id': 'some-other-job',
        'lat': 6.25,
        'lng': -75.57,
      }));
      await tick();

      expect(bloc.state.driverPosition, isNull);

      await bloc.close();
    });

    test('clears the driver position once the customer abandons matching',
        () async {
      final (bloc, channel, jobId) = await assignedBlocWithSocket();
      channel.addServerMessage(jsonEncode({
        'type': 'driver_location',
        'job_id': jobId,
        'lat': 6.25,
        'lng': -75.57,
      }));
      await tick();
      expect(bloc.state.driverPosition, isNotNull);

      bloc.add(const RequestMatchingAbandoned());
      await tick();

      expect(bloc.state.driverPosition, isNull);

      await bloc.close();
    });
  });
}
