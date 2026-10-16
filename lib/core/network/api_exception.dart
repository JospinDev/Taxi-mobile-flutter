import 'package:dio/dio.dart';

/// Normalized error surfaced by the API layer.
///
/// The Django backend returns either:
/// * `{"detail": "..."}` for global errors, or
/// * `{"field": ["message", ...]}` for field validation errors.
/// [fieldErrors] keeps the per-field mapping so forms can highlight inputs.
class ApiException implements Exception {
  const ApiException({
    required this.message,
    this.statusCode,
    this.fieldErrors = const {},
    this.raw,
  });

  final String message;
  final int? statusCode;
  final Map<String, List<String>> fieldErrors;
  final Object? raw;

  bool get isNetwork =>
      statusCode == null &&
      raw is DioException &&
      (raw as DioException).type != DioExceptionType.badResponse;
  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isValidation => statusCode == 400 || statusCode == 422;

  /// Builds an [ApiException] from any error thrown by Dio.
  factory ApiException.fromObject(Object error) {
    if (error is! DioException) {
      return ApiException(message: error.toString(), raw: error);
    }

    final response = error.response;
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError) {
      return const ApiException(
        message:
            'Connexion impossible. Vérifiez votre accès internet et réessayez.',
        raw: null,
      )._copyRaw(error);
    }
    if (error.type == DioExceptionType.cancel) {
      return ApiException(message: 'Requête annulée.', raw: error);
    }

    final status = response?.statusCode;
    final data = response?.data;
    var message = 'Une erreur est survenue. Veuillez réessayer.';
    var fieldErrors = <String, List<String>>{};

    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      final detail = map['detail'];
      if (detail is String && detail.trim().isNotEmpty) {
        message = detail;
      }
      fieldErrors = map.entries
          .where((e) => e.key != 'detail' && e.value is List)
          .fold(<String, List<String>>{}, (acc, entry) {
            acc[entry.key] = (entry.value as List)
                .map((e) => '$e')
                .toList(growable: false);
            return acc;
          });
      if (fieldErrors.isNotEmpty && detail is! String) {
        message = fieldErrors.values.expand((v) => v).first;
      }
    } else if (data is String && data.trim().isNotEmpty) {
      message = data;
    } else if (status != null) {
      message = _defaultMessageFor(status);
    }

    return ApiException(
      message: message,
      statusCode: status,
      fieldErrors: fieldErrors,
      raw: error,
    );
  }

  ApiException _copyRaw(Object error) => ApiException(
    message: message,
    statusCode: statusCode,
    fieldErrors: fieldErrors,
    raw: error,
  );

  static String _defaultMessageFor(int status) {
    switch (status) {
      case 400:
        return 'Requête invalide.';
      case 401:
        return 'Session expirée. Veuillez vous reconnecter.';
      case 403:
        return 'Vous n\'avez pas les droits nécessaires.';
      case 404:
        return 'Ressource introuvable.';
      case 413:
        return 'Fichier trop volumineux (5 Mo maximum).';
      case >= 500:
        return 'Le serveur rencontre un problème. Réessayez plus tard.';
      default:
        return 'Une erreur est survenue.';
    }
  }

  @override
  String toString() => 'ApiException($statusCode): $message';
}
