import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:the_crane/core/ws/crane_socket.dart';
import 'package:the_crane/core/ws/server_message.dart';

import '../../support/fake_web_socket_channel.dart';

void main() {
  group('connect()', () {
    test('is idempotent -- a second call never opens a second channel',
        () async {
      var openCount = 0;
      final socket = CraneSocket(
        channelFactory: (_) {
          openCount++;
          return FakeWebSocketChannel();
        },
      );

      socket.connect();
      socket.connect();
      await Future<void>.delayed(const Duration(milliseconds: 5));

      expect(openCount, 1);
      expect(socket.status, CraneSocketStatus.connected);
      await socket.dispose();
    });

    test('after dispose() is a permanent no-op', () async {
      final socket = CraneSocket(
        channelFactory: (_) => throw StateError('should not connect'),
      );
      await socket.dispose();

      socket.connect();
      await Future<void>.delayed(const Duration(milliseconds: 5));

      expect(socket.status, CraneSocketStatus.disconnected);
    });
  });

  group('connection failures', () {
    test('channel.ready throwing is caught and schedules a reconnect',
        () async {
      var openCount = 0;
      final statuses = <CraneSocketStatus>[];
      final socket = CraneSocket(
        channelFactory: (_) {
          openCount++;
          return FakeWebSocketChannel(readyError: 'boom');
        },
        initialBackoff: const Duration(minutes: 5),
      );
      socket.statusStream.listen(statuses.add);

      socket.connect();
      await Future<void>.delayed(const Duration(milliseconds: 5));

      expect(openCount, 1);
      expect(socket.status, CraneSocketStatus.disconnected);
      expect(
        statuses,
        [CraneSocketStatus.connecting, CraneSocketStatus.disconnected],
      );
      await socket.dispose();
    });

    test('the channel factory itself throwing is caught the same way',
        () async {
      final socket = CraneSocket(
        channelFactory: (_) => throw StateError('refused'),
        initialBackoff: const Duration(minutes: 5),
      );

      socket.connect();
      await Future<void>.delayed(const Duration(milliseconds: 5));

      expect(socket.status, CraneSocketStatus.disconnected);
      await socket.dispose();
    });

    test('reconnects automatically once the backoff delay elapses',
        () async {
      var openCount = 0;
      final socket = CraneSocket(
        channelFactory: (_) {
          openCount++;
          // Only the first attempt fails; the retry succeeds.
          return FakeWebSocketChannel(
            readyError: openCount == 1 ? 'boom' : null,
          );
        },
        initialBackoff: const Duration(milliseconds: 20),
        maxBackoff: const Duration(milliseconds: 20),
      );

      socket.connect();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(openCount, 1);
      expect(socket.status, CraneSocketStatus.disconnected);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(openCount, 2);
      expect(socket.status, CraneSocketStatus.connected);
      await socket.dispose();
    });

    test(
      'a stale connect attempt superseded by reconnectNow bails out '
      'once its token resolves, instead of opening a second channel',
      () async {
        final openedChannels = <FakeWebSocketChannel>[];
        final tokenCompleters = <Completer<String?>>[];
        final socket = CraneSocket(
          channelFactory: (_) {
            final channel = FakeWebSocketChannel();
            openedChannels.add(channel);
            return channel;
          },
          tokenProvider: () {
            final completer = Completer<String?>();
            tokenCompleters.add(completer);
            return completer.future;
          },
        );

        socket.connect();
        await Future<void>.delayed(const Duration(milliseconds: 1));
        expect(tokenCompleters.length, 1);
        expect(openedChannels, isEmpty);

        // Status is still `connecting`, not `connected` yet, so this is
        // allowed through and starts a second, superseding attempt.
        socket.reconnectNow();
        await Future<void>.delayed(const Duration(milliseconds: 1));
        expect(tokenCompleters.length, 2);

        tokenCompleters[1].complete('tok-fresh');
        await Future<void>.delayed(const Duration(milliseconds: 5));
        expect(openedChannels.length, 1);
        expect(socket.status, CraneSocketStatus.connected);

        // The stale first attempt's token finally resolves -- it must not
        // open a second channel or disturb the now-connected status.
        tokenCompleters[0].complete('tok-stale');
        await Future<void>.delayed(const Duration(milliseconds: 5));
        expect(openedChannels.length, 1);
        expect(socket.status, CraneSocketStatus.connected);

        await socket.dispose();
      },
    );

    test(
      'a stale attempt superseded while its channel is mid-connect closes '
      'that channel instead of adopting it',
      () async {
        final staleReadyGate = Completer<void>();
        FakeWebSocketChannel? staleChannel;
        FakeWebSocketChannel? freshChannel;
        var openCount = 0;
        final socket = CraneSocket(
          channelFactory: (_) {
            openCount++;
            if (openCount == 1) {
              staleChannel = FakeWebSocketChannel(
                readyGate: staleReadyGate.future,
              );
              return staleChannel!;
            }
            freshChannel = FakeWebSocketChannel();
            return freshChannel!;
          },
        );

        socket.connect();
        // The first attempt is stuck waiting on `ready`.
        await Future<void>.delayed(const Duration(milliseconds: 5));
        expect(openCount, 1);
        expect(socket.status, CraneSocketStatus.connecting);

        // Status is still `connecting`, so this is allowed through and
        // starts a second attempt that connects fully.
        socket.reconnectNow();
        await Future<void>.delayed(const Duration(milliseconds: 5));
        expect(openCount, 2);
        expect(socket.status, CraneSocketStatus.connected);

        // The stale first attempt's channel finally becomes ready -- it
        // must be closed rather than adopted as the live channel.
        staleReadyGate.complete();
        await Future<void>.delayed(const Duration(milliseconds: 5));

        expect(staleChannel!.sinkClosed, isTrue);
        expect(freshChannel!.sinkClosed, isFalse);
        expect(socket.status, CraneSocketStatus.connected);

        await socket.dispose();
      },
    );

    test('a stream error triggers the same reconnect path as a clean close',
        () async {
      var openCount = 0;
      FakeWebSocketChannel? channel;
      final socket = CraneSocket(
        channelFactory: (_) {
          openCount++;
          channel = FakeWebSocketChannel();
          return channel!;
        },
        initialBackoff: const Duration(milliseconds: 5),
      );

      socket.connect();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(openCount, 1);

      channel!.errorFromServer(Exception('transport blew up'));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(openCount, 2);
      expect(socket.status, CraneSocketStatus.connected);
      await socket.dispose();
    });
  });

  group('_onData message handling', () {
    test('a ping frame is answered with pong and forwarded as a message',
        () async {
      FakeWebSocketChannel? channel;
      final sent = <dynamic>[];
      final socket = CraneSocket(
        channelFactory: (_) {
          channel = FakeWebSocketChannel();
          channel!.sentMessages.listen(sent.add);
          return channel!;
        },
      );
      final messages = <ServerMessage>[];
      socket.messages.listen(messages.add);

      socket.connect();
      await Future<void>.delayed(const Duration(milliseconds: 5));

      channel!.addServerMessage('{"type":"ping"}');
      await Future<void>.delayed(const Duration(milliseconds: 5));

      expect(messages, [const ServerMessage.ping()]);
      expect(sent, ['{"type":"pong"}']);
      await socket.dispose();
    });

    test('a well-formed non-ping frame is forwarded without a pong reply',
        () async {
      FakeWebSocketChannel? channel;
      final sent = <dynamic>[];
      final socket = CraneSocket(
        channelFactory: (_) {
          channel = FakeWebSocketChannel();
          channel!.sentMessages.listen(sent.add);
          return channel!;
        },
      );
      final messages = <ServerMessage>[];
      socket.messages.listen(messages.add);

      socket.connect();
      await Future<void>.delayed(const Duration(milliseconds: 5));

      channel!.addServerMessage(
        '{"type":"job_event","job_id":"job-1","status":"assigned"}',
      );
      await Future<void>.delayed(const Duration(milliseconds: 5));

      expect(
        messages,
        [const ServerMessage.jobEvent(jobId: 'job-1', status: 'assigned')],
      );
      expect(sent, isEmpty);
      await socket.dispose();
    });

    test('malformed JSON is dropped without crashing the listener',
        () async {
      FakeWebSocketChannel? channel;
      final socket = CraneSocket(
        channelFactory: (_) {
          channel = FakeWebSocketChannel();
          return channel!;
        },
      );
      final messages = <ServerMessage>[];
      socket.messages.listen(messages.add);

      socket.connect();
      await Future<void>.delayed(const Duration(milliseconds: 5));

      channel!.addServerMessage('not json{{{');
      // A well-formed frame right after proves the listener survived.
      channel!.addServerMessage('{"type":"ping"}');
      await Future<void>.delayed(const Duration(milliseconds: 5));

      expect(messages, [const ServerMessage.ping()]);
      await socket.dispose();
    });

    test('a JSON frame that decodes to something other than an object '
        'is ignored', () async {
      FakeWebSocketChannel? channel;
      final socket = CraneSocket(
        channelFactory: (_) {
          channel = FakeWebSocketChannel();
          return channel!;
        },
      );
      final messages = <ServerMessage>[];
      socket.messages.listen(messages.add);

      socket.connect();
      await Future<void>.delayed(const Duration(milliseconds: 5));

      channel!.addServerMessage('[1,2,3]');
      channel!.addServerMessage('{"type":"ping"}');
      await Future<void>.delayed(const Duration(milliseconds: 5));

      expect(messages, [const ServerMessage.ping()]);
      await socket.dispose();
    });

    test('a non-string frame is ignored', () async {
      FakeWebSocketChannel? channel;
      final socket = CraneSocket(
        channelFactory: (_) {
          channel = FakeWebSocketChannel();
          return channel!;
        },
      );
      final messages = <ServerMessage>[];
      socket.messages.listen(messages.add);

      socket.connect();
      await Future<void>.delayed(const Duration(milliseconds: 5));

      channel!.addNonStringServerMessage(<int>[1, 2, 3]);
      channel!.addServerMessage('{"type":"ping"}');
      await Future<void>.delayed(const Duration(milliseconds: 5));

      expect(messages, [const ServerMessage.ping()]);
      await socket.dispose();
    });
  });

  group('subscribe / unsubscribe / sendLocation', () {
    test('subscribe before connect is queued and sent once connected',
        () async {
      final sent = <dynamic>[];
      final socket = CraneSocket(
        channelFactory: (_) {
          final channel = FakeWebSocketChannel();
          channel.sentMessages.listen(sent.add);
          return channel;
        },
      );

      socket.subscribe('job-1');
      socket.connect();
      await Future<void>.delayed(const Duration(milliseconds: 5));

      expect(sent, ['{"type":"subscribe","job_id":"job-1"}']);
      await socket.dispose();
    });

    test('subscribe/sendLocation while disconnected never throw', () async {
      final socket = CraneSocket(
        channelFactory: (_) => throw StateError('never connects'),
      );

      expect(() => socket.subscribe('job-1'), returnsNormally);
      expect(() => socket.sendLocation('job-1', 1.0, 2.0), returnsNormally);
      expect(() => socket.unsubscribe('job-1'), returnsNormally);
    });

    test(
      'unsubscribe stops the job from being resent on the next reconnect',
      () async {
        var openCount = 0;
        FakeWebSocketChannel? channel;
        final sent = <dynamic>[];
        final socket = CraneSocket(
          channelFactory: (_) {
            openCount++;
            channel = FakeWebSocketChannel();
            channel!.sentMessages.listen(sent.add);
            return channel!;
          },
          initialBackoff: const Duration(milliseconds: 5),
        );

        socket.connect();
        await Future<void>.delayed(const Duration(milliseconds: 5));
        socket.subscribe('job-1');
        await Future<void>.delayed(const Duration(milliseconds: 5));
        expect(sent, contains('{"type":"subscribe","job_id":"job-1"}'));

        socket.unsubscribe('job-1');
        await Future<void>.delayed(const Duration(milliseconds: 5));
        expect(sent.last, '{"type":"unsubscribe","job_id":"job-1"}');

        sent.clear();
        await channel!.closeFromServer();
        await Future<void>.delayed(const Duration(milliseconds: 30));

        expect(openCount, 2);
        expect(socket.status, CraneSocketStatus.connected);
        expect(sent, isEmpty);
        await socket.dispose();
      },
    );

    test('sendLocation sends a location frame while connected', () async {
      final sent = <dynamic>[];
      final socket = CraneSocket(
        channelFactory: (_) {
          final channel = FakeWebSocketChannel();
          channel.sentMessages.listen(sent.add);
          return channel;
        },
      );

      socket.connect();
      await Future<void>.delayed(const Duration(milliseconds: 5));

      socket.sendLocation('job-1', 6.24, -75.58);
      await Future<void>.delayed(const Duration(milliseconds: 5));

      expect(
        sent,
        ['{"type":"location","job_id":"job-1","lat":6.24,"lng":-75.58}'],
      );
      await socket.dispose();
    });
  });

  group('_wsUri', () {
    test('https base url maps to wss and appends the token query param',
        () async {
      Uri? capturedUri;
      final socket = CraneSocket(
        baseUrl: 'https://api.example.com',
        tokenProvider: () async => 'tok-abc',
        channelFactory: (uri) {
          capturedUri = uri;
          return FakeWebSocketChannel();
        },
      );

      socket.connect();
      await Future<void>.delayed(const Duration(milliseconds: 5));

      expect(capturedUri, isNotNull);
      expect(capturedUri!.scheme, 'wss');
      expect(capturedUri!.path, '/v1/ws');
      expect(capturedUri!.queryParameters['token'], 'tok-abc');
      await socket.dispose();
    });

    test(
      'http base url maps to ws and omits the query param when no token '
      'is provided',
      () async {
        Uri? capturedUri;
        final socket = CraneSocket(
          baseUrl: 'http://localhost:8000',
          channelFactory: (uri) {
            capturedUri = uri;
            return FakeWebSocketChannel();
          },
        );

        socket.connect();
        await Future<void>.delayed(const Duration(milliseconds: 5));

        expect(capturedUri, isNotNull);
        expect(capturedUri!.scheme, 'ws');
        expect(capturedUri!.queryParameters, isEmpty);
        await socket.dispose();
      },
    );
  });

  group('dispose()', () {
    test('closes the underlying channel sink', () async {
      FakeWebSocketChannel? channel;
      final socket = CraneSocket(
        channelFactory: (_) {
          channel = FakeWebSocketChannel();
          return channel!;
        },
      );

      socket.connect();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(socket.status, CraneSocketStatus.connected);

      await socket.dispose();

      expect(channel!.sinkClosed, isTrue);
    });
  });

  group('CraneSocket.reconnectNow (DRV-2)', () {
    test('is a no-op before connect() has been called', () async {
      final socket = CraneSocket(
        channelFactory: (_) => throw StateError('should not connect'),
      );

      socket.reconnectNow();

      expect(socket.status, CraneSocketStatus.disconnected);
    });

    test('is a no-op while already connected', () async {
      var openCount = 0;
      final socket = CraneSocket(
        channelFactory: (_) {
          openCount++;
          return FakeWebSocketChannel();
        },
      );
      socket.connect();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(socket.status, CraneSocketStatus.connected);

      socket.reconnectNow();
      await Future<void>.delayed(const Duration(milliseconds: 5));

      expect(openCount, 1);
      expect(socket.status, CraneSocketStatus.connected);
    });

    test('skips the pending backoff wait and reconnects immediately',
        () async {
      var openCount = 0;
      FakeWebSocketChannel? channel;
      final socket = CraneSocket(
        channelFactory: (_) {
          openCount++;
          channel = FakeWebSocketChannel();
          return channel!;
        },
        // Long enough that a passing test proves reconnectNow skipped it
        // rather than the backoff timer just happening to fire in time.
        initialBackoff: const Duration(minutes: 5),
      );
      socket.connect();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(openCount, 1);

      // Server drops the connection -- the socket schedules a reconnect
      // 5 minutes out.
      await channel!.closeFromServer();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(socket.status, CraneSocketStatus.disconnected);
      expect(openCount, 1);

      socket.reconnectNow();
      await Future<void>.delayed(const Duration(milliseconds: 5));

      expect(openCount, 2);
      expect(socket.status, CraneSocketStatus.connected);
    });
  });
}
