import 'dart:async';

import 'package:async/async.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// In-memory [WebSocketChannel] double for testing [CraneSocket] without a
/// real socket. The test plays the server: push a frame with
/// [addServerMessage], read what the client sent via [sentMessages], sever
/// the link with [closeFromServer].
class FakeWebSocketChannel with StreamChannelMixin implements WebSocketChannel {
  FakeWebSocketChannel({this.readyError, Future<void>? readyGate})
      : _readyGate = readyGate;

  /// When set, [ready] completes with this error instead of resolving —
  /// simulates a connect-time failure (DNS, refused connection, ...).
  final Object? readyError;

  /// When set, [ready] doesn't resolve until this future does — lets a test
  /// hold a connect attempt open (channel created, not yet "ready") to race
  /// another attempt against it. Ignored when [readyError] is also set.
  final Future<void>? _readyGate;

  final StreamController<dynamic> _incoming =
      StreamController<dynamic>.broadcast();
  final StreamController<dynamic> _outgoing =
      StreamController<dynamic>.broadcast();

  bool _sinkClosed = false;
  bool get sinkClosed => _sinkClosed;

  /// Raw frames the code under test sent via `sink.add`.
  Stream<dynamic> get sentMessages => _outgoing.stream;

  /// Simulates the server pushing a text frame to the client.
  void addServerMessage(String raw) {
    if (!_incoming.isClosed) _incoming.add(raw);
  }

  /// Simulates the server pushing a non-text frame (e.g. binary) — real
  /// `web_socket_channel` streams can emit these; [CraneSocket] guards
  /// against decoding anything that isn't a [String].
  void addNonStringServerMessage(Object raw) {
    if (!_incoming.isClosed) _incoming.add(raw);
  }

  /// Simulates the server dropping the connection.
  Future<void> closeFromServer() => _incoming.close();

  /// Simulates the transport erroring out (as opposed to a clean
  /// [closeFromServer]) — `CraneSocket` treats both the same way.
  void errorFromServer(Object error) {
    if (!_incoming.isClosed) _incoming.addError(error);
  }

  @override
  Stream get stream => _incoming.stream;

  @override
  late final WebSocketSink sink = _FakeWebSocketSink(_outgoing, this);

  @override
  Future<void> get ready {
    if (readyError != null) return Future<void>.error(readyError!);
    return _readyGate ?? Future.value();
  }

  @override
  String? get protocol => null;

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;
}

class _FakeWebSocketSink extends DelegatingStreamSink implements WebSocketSink {
  _FakeWebSocketSink(this._controller, this._owner) : super(_controller.sink);

  final StreamController<dynamic> _controller;
  final FakeWebSocketChannel _owner;

  @override
  Future close([int? closeCode, String? closeReason]) {
    _owner._sinkClosed = true;
    return _controller.close();
  }
}
