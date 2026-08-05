import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/env.dart';
import 'server_message.dart';

/// Opens a new WebSocket transport for [uri]. Injected so tests can
/// substitute a fake channel (see `test/support/fake_web_socket_channel.dart`)
/// instead of touching a real socket — the only seam [CraneSocket] needs for
/// unit testing.
typedef WebSocketChannelFactory = WebSocketChannel Function(Uri uri);

/// Resolves the current user's Firebase ID token for the `?token=` query
/// param `WS /v1/ws` requires (see `backend/app/api/ws.py`).
///
/// TODO(FND-1): once Firebase is wired, return
/// `await FirebaseAuth.instance.currentUser?.getIdToken()` here — the same
/// seam `AuthInterceptor` (`lib/core/api/auth_interceptor.dart`) stubs for
/// REST calls. Until then this returns null, the socket connects without a
/// token, and the backend closes it with code 4001 (expected/documented).
typedef WsTokenProvider = Future<String?> Function();

Future<String?> _defaultTokenProvider() async => null;

/// [CraneSocket]'s connection lifecycle, exposed so repositories can decide
/// whether to trust push updates or fall back to polling.
enum CraneSocketStatus { disconnected, connecting, connected }

/// Realtime client for `WS /v1/ws` (TRK-1/2/3): job status pushes, driver
/// location relays, and job offers direct to a driver — the channel
/// `ApiJobsRepository`/`ApiDriversRepository` prefer once connected, falling
/// back to their original poll loops otherwise.
///
/// Reconnects with capped exponential backoff (starts at [initialBackoff],
/// doubles, caps at [maxBackoff]) and re-sends `subscribe` for every job id a
/// caller had asked for, so a caller never needs to notice a drop.
class CraneSocket {
  CraneSocket({
    String? baseUrl,
    WebSocketChannelFactory? channelFactory,
    WsTokenProvider? tokenProvider,
    this.initialBackoff = const Duration(seconds: 1),
    this.maxBackoff = const Duration(seconds: 30),
  })  : _baseUrl = baseUrl ?? Env.apiBaseUrl,
        _channelFactory = channelFactory ?? WebSocketChannel.connect,
        _tokenProvider = tokenProvider ?? _defaultTokenProvider,
        _backoff = initialBackoff;

  final String _baseUrl;
  final WebSocketChannelFactory _channelFactory;
  final WsTokenProvider _tokenProvider;

  /// Delay before the first reconnect attempt.
  final Duration initialBackoff;

  /// Reconnect delay never grows past this.
  final Duration maxBackoff;

  final StreamController<ServerMessage> _messages =
      StreamController<ServerMessage>.broadcast();
  final StreamController<CraneSocketStatus> _statusController =
      StreamController<CraneSocketStatus>.broadcast();

  /// Job ids a caller has asked to hear about; resent as `subscribe` on
  /// every (re)connect.
  final Set<String> _subscribedJobIds = {};

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _channelSub;
  Timer? _reconnectTimer;
  Duration _backoff;
  bool _disposed = false;
  bool _started = false;
  int _connectAttempt = 0;

  CraneSocketStatus _status = CraneSocketStatus.disconnected;
  CraneSocketStatus get status => _status;

  /// Every parsed push from the server.
  Stream<ServerMessage> get messages => _messages.stream;

  /// Connection status changes.
  Stream<CraneSocketStatus> get statusStream => _statusController.stream;

  /// Opens the connection. Idempotent — safe to call from every repository
  /// method that wants the socket up; only the first call does anything.
  void connect() {
    if (_disposed || _started) return;
    _started = true;
    unawaited(_open());
  }

  Future<void> _open() async {
    _setStatus(CraneSocketStatus.connecting);
    final attempt = ++_connectAttempt;
    try {
      final token = await _tokenProvider();
      if (_disposed || attempt != _connectAttempt) return;
      final channel = _channelFactory(_wsUri(token));
      await channel.ready;
      if (_disposed || attempt != _connectAttempt) {
        await channel.sink.close();
        return;
      }
      _channel = channel;
      _backoff = initialBackoff;
      _channelSub = channel.stream.listen(
        _onData,
        onDone: _onDisconnected,
        onError: (Object _, StackTrace _) => _onDisconnected(),
        cancelOnError: true,
      );
      _setStatus(CraneSocketStatus.connected);
      // Re-subscribe to whatever the caller had asked for before the drop
      // (or before this very first connect, if `subscribe` raced `connect`).
      for (final jobId in _subscribedJobIds) {
        _send({'type': 'subscribe', 'job_id': jobId});
      }
    } catch (_) {
      if (_disposed || attempt != _connectAttempt) return;
      _scheduleReconnect();
    }
  }

  Uri _wsUri(String? token) {
    final httpUri = Uri.parse(_baseUrl);
    final scheme = httpUri.scheme == 'https' ? 'wss' : 'ws';
    return httpUri.replace(
      scheme: scheme,
      path: '/v1/ws',
      queryParameters: token != null ? {'token': token} : null,
    );
  }

  void _onData(dynamic raw) {
    if (raw is! String) return;
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return;
    }
    if (decoded is! Map<String, dynamic>) return;
    final message = ServerMessage.fromWire(decoded);
    if (message is ServerMessagePing) {
      _send({'type': 'pong'});
    }
    _messages.add(message);
  }

  void _onDisconnected() {
    unawaited(_channelSub?.cancel());
    _channelSub = null;
    _channel = null;
    if (_disposed) return;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _setStatus(CraneSocketStatus.disconnected);
    _reconnectTimer?.cancel();
    final delay = _backoff;
    _reconnectTimer = Timer(delay, () {
      if (_disposed) return;
      unawaited(_open());
    });
    final nextMs = math.min(
      _backoff.inMilliseconds * 2,
      maxBackoff.inMilliseconds,
    );
    _backoff = Duration(milliseconds: nextMs);
  }

  void _setStatus(CraneSocketStatus status) {
    if (_status == status) return;
    _status = status;
    _statusController.add(status);
  }

  void _send(Map<String, dynamic> payload) {
    if (_channel == null || _status != CraneSocketStatus.connected) return;
    _channel!.sink.add(jsonEncode(payload));
  }

  /// Joins a job's event stream. Remembered so a reconnect resubscribes
  /// automatically; safe to call before the socket has finished connecting
  /// (the subscribe is just queued for the next successful connect).
  void subscribe(String jobId) {
    _subscribedJobIds.add(jobId);
    _send({'type': 'subscribe', 'job_id': jobId});
  }

  /// Leaves a job's event stream.
  void unsubscribe(String jobId) {
    _subscribedJobIds.remove(jobId);
    _send({'type': 'unsubscribe', 'job_id': jobId});
  }

  /// Driver-only: reports a live fix for [jobId]. A no-op while disconnected
  /// — callers don't need to buffer, the next fix a few seconds later is
  /// good enough (TRK-2's Redis key + snapshot cadence is already ~5s).
  void sendLocation(String jobId, double lat, double lng) {
    _send({'type': 'location', 'job_id': jobId, 'lat': lat, 'lng': lng});
  }

  Future<void> dispose() async {
    _disposed = true;
    _reconnectTimer?.cancel();
    await _channelSub?.cancel();
    await _channel?.sink.close();
    await _messages.close();
    await _statusController.close();
  }
}
