import 'dart:io';

abstract interface class RealtimeSocket {
  Stream<String> get messages;
  Future<void> get done;
  Future<void> close();
}

final class _IoRealtimeSocket implements RealtimeSocket {
  _IoRealtimeSocket(this._socket);

  final WebSocket _socket;

  @override
  Stream<String> get messages =>
      _socket.where((event) => event is String).cast<String>();

  @override
  Future<void> get done => _socket.done.then<void>((_) {});

  @override
  Future<void> close() => _socket.close(WebSocketStatus.normalClosure);
}

Future<RealtimeSocket> connectRealtimeSocket(Uri uri) async =>
    _IoRealtimeSocket(await WebSocket.connect(uri.toString()));
