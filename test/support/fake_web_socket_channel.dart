import 'dart:async';

import 'package:async/async.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// In-memory [WebSocketChannel] double for testing [CraneSocket] without a
/// real socket. The test plays the server: push a frame with
/// [addServerMessage], read what the client sent via [sentMessages], sever
/// the link with [closeFromServer].
class FakeWebSocketChannel with StreamChannelMixin implements WebSocketChannel {
  FakeWebSocketChannel({this.readyError});

  /// When set, [ready] completes with this error instead of resolving —
  /// simulates a connect-time failure (DNS, refused connection, ...).
  final Object? readyError;

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

  /// Simulates the server dropping the connection.
  Future<void> closeFromServer() => _incoming.close();

  @override
  Stream get stream => _incoming.stream;

  @override
  late final WebSocketSink sink = _FakeWebSocketSink(_outgoing, this);

  @override
  Future<void> get ready =>
      readyError != null ? Future<void>.error(readyError!) : Future.value();

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
