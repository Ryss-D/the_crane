import 'package:flutter_test/flutter_test.dart';
import 'package:the_crane/core/ws/crane_socket.dart';

import '../../support/fake_web_socket_channel.dart';

void main() {
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
