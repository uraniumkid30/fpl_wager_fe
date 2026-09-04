import 'package:dio/dio.dart';
import 'package:fpl_wager/core/errors/app_exception.dart';

class ApiClient {
  ApiClient(String baseUrl)
      : _dio = Dio(
          BaseOptions(
            baseUrl: '${baseUrl.replaceFirst(RegExp(r'/+$'), '')}/v1',
            connectTimeout: const Duration(seconds: 8),
            receiveTimeout: const Duration(seconds: 12),
            headers: const {'Accept': 'application/json'},
          ),
        );

  final Dio _dio;
  Future<String?> Function()? _refreshHandler;

  void setRefreshHandler(Future<String?> Function() handler) {
    _refreshHandler = handler;
  }

  void authorize(String? token) {
    if (token == null) {
      _dio.options.headers.remove('Authorization');
    } else {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    }
  }

  Future<Map<String, Object?>> get(String path, {Map<String, Object?>? query}) =>
      _request(() => _dio.get<Object?>(path, queryParameters: query));

  Future<Map<String, Object?>> post(
    String path, {
    Map<String, Object?>? data,
    String? idempotencyKey,
    bool allowRefresh = true,
  }) =>
      _request(
        () => _dio.post<Object?>(
          path,
          data: data,
          options: Options(
            headers: idempotencyKey == null
                ? null
                : {'Idempotency-Key': idempotencyKey},
          ),
        ),
        allowRefresh: allowRefresh,
      );

  Future<Map<String, Object?>> put(
    String path, {
    Map<String, Object?>? data,
  }) =>
      _request(() => _dio.put<Object?>(path, data: data));

  Future<Map<String, Object?>> patch(
    String path, {
    Map<String, Object?>? data,
  }) => _request(() => _dio.patch<Object?>(path, data: data));

  Future<Map<String, Object?>> delete(String path) =>
      _request(() => _dio.delete<Object?>(path));

  Future<Map<String, Object?>> _request(
    Future<Response<Object?>> Function() execute,
    {bool allowRefresh = true}
  ) async {
    try {
      final response = await execute();
      if (response.data == null) return const {};
      return Map<String, Object?>.from(response.data! as Map<Object?, Object?>);
    } on DioException catch (error) {
      if (error.response?.statusCode == 401 && allowRefresh && _refreshHandler != null) {
        final token = await _refreshHandler!();
        if (token != null) {
          authorize(token);
          return _request(execute, allowRefresh: false);
        }
      }
      final data = error.response?.data;
      String? code;
      String message = 'Unable to connect. Please try again.';
      if (data is Map<Object?, Object?> && data['error'] is Map<Object?, Object?>) {
        final body = data['error']! as Map<Object?, Object?>;
        code = body['code'] as String?;
        message = body['message'] as String? ?? message;
      }
      if (error.response?.statusCode == 401) {
        throw AuthenticationException(message, code: code);
      }
      if ((error.response?.statusCode ?? 500) < 500) {
        throw ValidationException(message, code: code);
      }
      throw NetworkException(message, code: code);
    }
  }
}
