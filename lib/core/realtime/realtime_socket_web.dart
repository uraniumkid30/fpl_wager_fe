// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:html' as html;

abstract interface class RealtimeSocket {
  Stream<String> get messages;
  Future<void> get done;
  Future<void> close();
}

final class _WebRealtimeSocket implements RealtimeSocket {
  _WebRealtimeSocket(this._socket) {
    _socket.onMessage.listen((event) {
      final data = event.data;
      if (data is String) _messages.add(data);
    });
    _socket.onError.listen((_) {
      if (!_messages.isClosed) {
        _messages.addError(StateError('The realtime connection failed.'));
      }
      if (!_done.isCompleted) _done.complete();
    });
    _socket.onClose.listen((_) {
      if (!_messages.isClosed) _messages.close();
      if (!_done.isCompleted) _done.complete();
    });
  }

  final html.WebSocket _socket;
  final _messages = StreamController<String>.broadcast();
  final _done = Completer<void>();

  @override
  Stream<String> get messages => _messages.stream;

  @override
  Future<void> get done => _done.future;

  @override
  Future<void> close() async {
    _socket.close(1000, 'signed out');
    if (!_done.isCompleted) _done.complete();
    if (!_messages.isClosed) await _messages.close();
  }
}

Future<RealtimeSocket> connectRealtimeSocket(Uri uri) {
  final completer = Completer<RealtimeSocket>();
  final socket = html.WebSocket(uri.toString());
  late final StreamSubscription<html.Event> errorSubscription;
  late final StreamSubscription<html.Event> openSubscription;
  openSubscription = socket.onOpen.listen((_) {
    if (!completer.isCompleted) completer.complete(_WebRealtimeSocket(socket));
    errorSubscription.cancel();
    openSubscription.cancel();
  });
  errorSubscription = socket.onError.listen((_) {
    if (!completer.isCompleted) {
      completer.completeError(StateError('The realtime connection failed.'));
    }
    errorSubscription.cancel();
    openSubscription.cancel();
  });
  return completer.future.timeout(const Duration(seconds: 10));
}
