export 'realtime_socket_stub.dart'
    if (dart.library.io) 'realtime_socket_io.dart'
    if (dart.library.js_interop) 'realtime_socket_web.dart';
