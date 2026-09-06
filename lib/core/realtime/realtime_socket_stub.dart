abstract interface class RealtimeSocket {
  Stream<String> get messages;
  Future<void> get done;
  Future<void> close();
}

Future<RealtimeSocket> connectRealtimeSocket(Uri uri) =>
    Future.error(UnsupportedError('WebSockets are unavailable on this platform.'));
