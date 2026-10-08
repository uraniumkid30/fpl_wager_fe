import 'dart:async';
import 'dart:js_interop';

/// The live-update connection in a web browser.
///
/// It talks to the browser's own WebSocket through `dart:js_interop`, which
/// replaces the old `dart:html` (deprecated, and not available when the web
/// app is compiled to WebAssembly).
abstract interface class RealtimeSocket {
  Stream<String> get messages;
  Future<void> get done;
  Future<void> close();
}

/// The browser's `WebSocket`, only the parts used here.
@JS('WebSocket')
extension type _BrowserSocket._(JSObject _) implements JSObject {
  external factory _BrowserSocket(String url);

  external void close([int code, String reason]);
  external set onopen(JSFunction? handler);
  external set onmessage(JSFunction? handler);
  external set onerror(JSFunction? handler);
  external set onclose(JSFunction? handler);
}

/// A `message` event; [data] is the text the server sent.
extension type _MessageEvent._(JSObject _) implements JSObject {
  external JSAny? get data;
}

final class _WebRealtimeSocket implements RealtimeSocket {
  _WebRealtimeSocket(this._socket) {
    _socket.onmessage = ((_MessageEvent event) {
      // Text arrives as a JS string; anything else is not ours.
      final data = event.data.dartify();
      if (data is String && !_messages.isClosed) _messages.add(data);
    }).toJS;
    _socket.onerror = ((JSObject _) {
      if (!_messages.isClosed) {
        _messages.addError(StateError('The realtime connection failed.'));
      }
      if (!_done.isCompleted) _done.complete();
    }).toJS;
    _socket.onclose = ((JSObject _) {
      if (!_messages.isClosed) _messages.close();
      if (!_done.isCompleted) _done.complete();
    }).toJS;
  }

  final _BrowserSocket _socket;
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
  final socket = _open(uri);
  if (socket == null) {
    return Future.error(StateError('The realtime connection failed.'));
  }
  socket.onopen = ((JSObject _) {
    socket
      ..onopen = null
      ..onerror = null;
    if (!completer.isCompleted) completer.complete(_WebRealtimeSocket(socket));
  }).toJS;
  socket.onerror = ((JSObject _) {
    socket
      ..onopen = null
      ..onerror = null;
    if (!completer.isCompleted) {
      completer.completeError(StateError('The realtime connection failed.'));
    }
  }).toJS;
  return completer.future.timeout(
    const Duration(seconds: 10),
    onTimeout: () {
      // Nobody will use this connection now, so it is not left half-open.
      socket.close();
      throw TimeoutException('The realtime connection timed out.');
    },
  );
}

/// The browser refuses some addresses outright (a malformed URL, say).
_BrowserSocket? _open(Uri uri) {
  try {
    return _BrowserSocket(uri.toString());
  } on Object {
    return null;
  }
}
