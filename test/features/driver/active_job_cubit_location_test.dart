import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:the_crane/core/api/fake_drivers_repository.dart';
import 'package:the_crane/core/api/fake_jobs_repository.dart';
import 'package:the_crane/core/location/location_source.dart';
import 'package:the_crane/core/models/lat_lng.dart';
import 'package:the_crane/core/ws/crane_socket.dart';
import 'package:the_crane/features/driver/job/active_job_cubit.dart';

import '../../support/fake_web_socket_channel.dart';

/// TRK-5 test double: a controllable position stream, no real GPS/plugin.
class _FakeLocationSource implements LocationSource {
  final _controller = StreamController<LatLng>.broadcast();

  @override
  Future<bool> requestPermission() async => true;

  @override
  Stream<LatLng> watchPosition() => _controller.stream;

  void emit(LatLng fix) => _controller.add(fix);
}

void main() {
  test('sends the live GPS fix over the socket once one arrives, '
      'falling back to the pickup point before that', () async {
    final channel = FakeWebSocketChannel();
    final sent = <Map<String, dynamic>>[];
    channel.sentMessages.listen((raw) {
      sent.add(jsonDecode(raw as String) as Map<String, dynamic>);
    });

    final socket = CraneSocket(channelFactory: (_) => channel);
    socket.connect();
    await Future<void>.delayed(const Duration(milliseconds: 5)); // fake ready

    final jobs = FakeJobsRepository(actionDelay: Duration.zero);
    final drivers = FakeDriversRepository(jobs: jobs, actionDelay: Duration.zero);
    final location = _FakeLocationSource();
    final cubit = ActiveJobCubit(
      jobsRepository: jobs,
      socket: socket,
      locationSource: location,
      locationInterval: const Duration(milliseconds: 10),
    );

    final offer = drivers.debugTriggerOffer();
    final job = await jobs.acceptJob(offer.job.id); // status: assigned
    cubit.start(job);

    // No fix has arrived yet -> the timer falls back to the pickup point.
    await Future<void>.delayed(const Duration(milliseconds: 15));
    expect(sent, isNotEmpty);
    expect(sent.last['type'], 'location');
    expect(sent.last['lat'], job.pickup.lat);
    expect(sent.last['lng'], job.pickup.lng);

    // Once a live fix arrives, it takes over from the pickup point.
    location.emit(const LatLng(lat: 6.30, lng: -75.55));
    await Future<void>.delayed(const Duration(milliseconds: 15));
    expect(sent.last['lat'], 6.30);
    expect(sent.last['lng'], -75.55);

    cubit.clear();
    await cubit.close();
    await socket.dispose();
  });
}
