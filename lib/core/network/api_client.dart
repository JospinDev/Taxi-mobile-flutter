import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../storage/token_storage.dart';
import 'api_exception.dart';

/// HTTP layer built on Dio.
///
/// Responsibilities:
/// * attaches `Authorization: Bearer <access>` to every request,
/// * transparently refreshes the access token on 401 (single-flight) and
///   replays the failed request once,
/// * normalizes every failure into an [ApiException],
/// * exposes typed helpers (`getJson`, `postJson`, multipart upload...).
class ApiClient {
  ApiClient(this._storage) {
    dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
        contentType: 'application/json',
        responseType: ResponseType.json,
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = _storage.access;
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final shouldRetry = await _handleUnauthorized(error);
          if (shouldRetry != null) {
            return handler.resolve(shouldRetry);
          }
          handler.next(error);
        },
      ),
    );

    if (AppConfig.enableApiLogs && kDebugMode) {
      dio.interceptors.add(
        LogInterceptor(
          requestBody: false,
          responseBody: false,
          error: true,
          logPrint: (o) => debugPrint('[API] $o'),
        ),
      );
    }
  }

  final TokenStorage _storage;
  late final Dio dio;

  /// Single-flight refresh future: concurrent 401s share one refresh call.
  Future<String?>? _refreshing;

  // ───────────────────────────────── helpers ─────────────────────────────────

  /// Converts any Dio/Dart error into [ApiException].
  static ApiException normalize(Object error) => ApiException.fromObject(error);

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    try {
      final res = await dio.get(path, queryParameters: query);
      return res.data;
    } catch (e) {
      throw normalize(e);
    }
  }

  Future<dynamic> post(
    String path, {
    Object? data,
    Map<String, dynamic>? query,
  }) async {
    try {
      final res = await dio.post(
        path,
        data: data ?? const {},
        queryParameters: query,
      );
      return res.data;
    } catch (e) {
      throw normalize(e);
    }
  }

  Future<dynamic> patch(
    String path, {
    Object? data,
    Map<String, dynamic>? query,
  }) async {
    try {
      final res = await dio.patch(
        path,
        data: data ?? const {},
        queryParameters: query,
      );
      return res.data;
    } catch (e) {
      throw normalize(e);
    }
  }

  Future<void> delete(String path) async {
    try {
      await dio.delete(path);
    } catch (e) {
      throw normalize(e);
    }
  }

  /// Multipart upload (documents). [onSendProgress] drives upload indicators.
  Future<dynamic> upload(
    String path, {
    required FormData formData,
    void Function(int, int)? onSendProgress,
  }) async {
    try {
      final res = await dio.post(
        path,
        data: formData,
        onSendProgress: onSendProgress,
        options: Options(contentType: 'multipart/form-data'),
      );
      return res.data;
    } catch (e) {
      throw normalize(e);
    }
  }

  // ──────────────────────────── token refresh ────────────────────────────────

  /// Returns a "fixed" response to replay, or `null` to propagate the error.
  Future<Response?>? _handleUnauthorized(DioException error) async {
    final status = error.response?.statusCode;
    final path = error.requestOptions.path;
    final isRefreshCall = path.contains('token/refresh');
    if (status != 401 || isRefreshCall) return null;

    // No stored refresh token → session is dead, propagate.
    final refreshToken = _storage.refresh;
    if (refreshToken == null || refreshToken.isEmpty) return null;

    try {
      final newAccess = await (_refreshing ??= _refresh(refreshToken));
      final request = error.requestOptions;
      request.headers['Authorization'] = 'Bearer $newAccess';
      // Replays the original request with the fresh token.
      return await dio.fetch<dynamic>(request);
    } catch (_) {
      // Refresh failed (invalid/expired refresh token): clear the session so
      // the router sends the user back to login.
      await _storage.clear();
      return null;
    } finally {
      _refreshing = null;
    }
  }

  Future<String?> _refresh(String refreshToken) async {
    final res = await dio.post(
      'accounts/token/refresh/',
      data: {'refresh': refreshToken},
      options: Options(
        headers: {'Authorization': null}, // refresh endpoint is public
        contentType: 'application/json',
      ),
    );
    final data = res.data as Map<String, dynamic>;
    final access = data['access'] as String?;
    final newRefresh = data['refresh'] as String?;
    if (access == null) throw const ApiException(message: 'Session expirée.');
    await _storage.save(
      access: access,
      refresh: newRefresh ?? refreshToken,
      role: _storage.role ?? '',
    );
    return access;
  }
}
