import 'dart:convert';

import 'package:dio/dio.dart';

enum ApiErrorKind { network, timeout, unauthorized, forbidden, notFound, server, unknown }

/// Normalised error surfaced to the UI layer. Hides Dio internals and extracts
/// Frappe's human-readable messages from its error payloads.
class ApiException implements Exception {
  const ApiException(this.kind, this.message, {this.statusCode});

  final ApiErrorKind kind;
  final String message;
  final int? statusCode;

  bool get isAuthError =>
      kind == ApiErrorKind.unauthorized || kind == ApiErrorKind.forbidden;

  factory ApiException.fromDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiException(
          ApiErrorKind.timeout,
          'The server took too long to respond. Please try again.',
        );
      case DioExceptionType.connectionError:
      case DioExceptionType.unknown:
        return const ApiException(
          ApiErrorKind.network,
          'No connection. Check your internet and try again.',
        );
      case DioExceptionType.badCertificate:
        return const ApiException(
          ApiErrorKind.network,
          'Secure connection failed.',
        );
      case DioExceptionType.cancel:
        return const ApiException(ApiErrorKind.unknown, 'Request cancelled.');
      case DioExceptionType.badResponse:
        final code = e.response?.statusCode ?? 0;
        final msg = _extractMessage(e.response?.data);
        switch (code) {
          case 401:
            return ApiException(
              ApiErrorKind.unauthorized,
              msg ?? 'Your session has expired. Please sign in again.',
              statusCode: code,
            );
          case 403:
            return ApiException(
              ApiErrorKind.forbidden,
              msg ?? 'You do not have permission to do that.',
              statusCode: code,
            );
          case 404:
            return ApiException(
              ApiErrorKind.notFound,
              msg ?? 'Not found.',
              statusCode: code,
            );
          default:
            return ApiException(
              code >= 500 ? ApiErrorKind.server : ApiErrorKind.unknown,
              msg ?? 'Something went wrong (HTTP $code).',
              statusCode: code,
            );
        }
    }
  }

  /// Frappe returns errors in several shapes. `_server_messages` is a
  /// JSON-encoded list of JSON-encoded maps; decode it properly and extract
  /// real human messages. If everything is empty, return null so the caller
  /// can fall back to a status-based default.
  static String? _extractMessage(dynamic data) {
    if (data == null) return null;
    if (data is String && data.trim().isNotEmpty && !data.contains('<html')) {
      return data;
    }
    if (data is Map) {
      // 1) Properly decode _server_messages.
      final serverMsgs = data['_server_messages'];
      if (serverMsgs is String && serverMsgs.trim().isNotEmpty) {
        try {
          final outer = jsonDecode(serverMsgs);
          if (outer is List) {
            final pieces = <String>[];
            for (final item in outer) {
              try {
                final parsed = item is String ? jsonDecode(item) : item;
                if (parsed is Map) {
                  final m = parsed['message'];
                  if (m is String && m.trim().isNotEmpty) {
                    pieces.add(_stripHtml(m));
                  }
                }
              } catch (_) {}
            }
            if (pieces.isNotEmpty) return pieces.join(' ');
          }
        } catch (_) {/* fall through */}
      }
      // 2) Other common error keys.
      for (final key in ['message', 'exception', '_error_message']) {
        final v = data[key];
        if (v is String && v.trim().isNotEmpty) return _stripHtml(v);
      }
      // 3) Convert exception class to a friendly message.
      final excType = data['exc_type'];
      if (excType is String) {
        if (excType.contains('PermissionError')) {
          return 'You do not have permission to view this record.';
        }
        if (excType.contains('DoesNotExistError')) {
          return 'This record no longer exists.';
        }
        if (excType.contains('AuthenticationError')) {
          return 'Your session has expired. Please sign in again.';
        }
      }
    }
    return null;
  }

  static String _stripHtml(String s) => s
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();

  @override
  String toString() => 'ApiException($kind, $statusCode): $message';
}
