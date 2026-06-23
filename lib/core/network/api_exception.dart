import 'dart:convert';

import 'package:dio/dio.dart';

enum ApiErrorKind { network, timeout, unauthorized, forbidden, notFound, server, unknown }

/// Normalised error surfaced to the UI layer.
///
/// Hides Dio internals, extracts Frappe's human-readable messages from its
/// error payloads, and falls back to specific, actionable messages per HTTP
/// status code when no server message is available.
///
/// Design principle: every [message] should tell the user (a) WHAT went
/// wrong in plain language and (b) WHAT to try next. Never "Something went
/// wrong" — always say which side the problem is on and what they can do.
class ApiException implements Exception {
  const ApiException(this.kind, this.message, {this.statusCode});

  final ApiErrorKind kind;
  final String message;
  final int? statusCode;

  bool get isAuthError =>
      kind == ApiErrorKind.unauthorized || kind == ApiErrorKind.forbidden;

  factory ApiException.fromDio(DioException e) {
    switch (e.type) {
      // -------------------- Network / transport errors --------------------
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
        return const ApiException(
          ApiErrorKind.timeout,
          'Cannot reach the server. Check your internet connection and try again.',
        );
      case DioExceptionType.receiveTimeout:
        return const ApiException(
          ApiErrorKind.timeout,
          'The server is taking too long to respond. Please try again in a moment.',
        );
      case DioExceptionType.connectionError:
      case DioExceptionType.unknown:
        return _fromConnectionError(e);
      case DioExceptionType.badCertificate:
        return const ApiException(
          ApiErrorKind.network,
          "Secure connection failed — the server's certificate could not be verified. Contact TCB Infotech if this keeps happening.",
        );
      case DioExceptionType.cancel:
        return const ApiException(ApiErrorKind.unknown, 'Request cancelled.');

      // -------------------- HTTP status responses --------------------
      case DioExceptionType.badResponse:
        final code = e.response?.statusCode ?? 0;
        final serverMsg = _extractMessage(e.response?.data);
        return _fromHttpStatus(code, serverMsg);
    }
  }

  /// Distinguish "phone has no internet" from "server endpoint is unreachable".
  ///
  /// Dio collapses both into [DioExceptionType.connectionError] (and sometimes
  /// [DioExceptionType.unknown]) but the underlying `SocketException` text
  /// is different — and the user-facing fix is different too. "Check your
  /// Wi-Fi" is the wrong message when the device is online but the server
  /// URL is wrong / unreachable.
  static ApiException _fromConnectionError(DioException e) {
    final under = e.error?.toString().toLowerCase() ?? '';

    // Phone-side networking is genuinely down (no carrier, airplane mode,
    // Wi-Fi off, etc.).
    if (under.contains('network is unreachable') ||
        under.contains('software caused connection abort')) {
      return const ApiException(
        ApiErrorKind.network,
        "Can't connect to the internet. Check your Wi-Fi or mobile data and try again.",
      );
    }

    // DNS resolution failed — could be flaky connectivity OR the server
    // hostname is wrong / no longer exists.
    if (under.contains('failed host lookup')) {
      return const ApiException(
        ApiErrorKind.network,
        "Can't reach the server — the address could not be looked up. Check your internet, or contact TCB Infotech if you keep seeing this.",
      );
    }

    // Reachable but the port is closed — server is down OR the URL is wrong.
    // (e.g. a tenant configured with http://127.0.0.1:8002 that the phone
    // can never reach.)
    if (under.contains('connection refused') ||
        under.contains('no route to host') ||
        under.contains('connection reset')) {
      return const ApiException(
        ApiErrorKind.network,
        "Can't reach this company's server. The server may be down, or the URL configured for this company is unreachable. Contact TCB Infotech to check the configuration.",
      );
    }

    // Connection timed out — server is reachable but didn't respond in time,
    // or the route to it is slow.
    if (under.contains('timed out') || under.contains('timeout')) {
      return const ApiException(
        ApiErrorKind.timeout,
        "The server didn't respond in time. Check your internet and try again, or contact TCB Infotech if this keeps happening.",
      );
    }

    // Generic — don't know which side it's on. Tell the user honestly that
    // it could be either, and what to try.
    return const ApiException(
      ApiErrorKind.network,
      "Couldn't reach the server. This could be a network problem on your side, or the server is unavailable. Try again — contact TCB Infotech if this keeps happening.",
    );
  }

  static ApiException _fromHttpStatus(int code, String? serverMsg) {
    switch (code) {
      case 400:
        return ApiException(
          ApiErrorKind.unknown,
          serverMsg ??
              'The request was invalid. Please check the form and try again.',
          statusCode: code,
        );
      case 401:
        return ApiException(
          ApiErrorKind.unauthorized,
          serverMsg ?? 'Your session has expired. Please sign in again.',
          statusCode: code,
        );
      case 403:
        return ApiException(
          ApiErrorKind.forbidden,
          serverMsg ?? "You don't have permission to do this.",
          statusCode: code,
        );
      case 404:
        return ApiException(
          ApiErrorKind.notFound,
          serverMsg ??
              "The record you're looking for no longer exists, or you don't have access to it.",
          statusCode: code,
        );
      case 408:
        return ApiException(
          ApiErrorKind.timeout,
          serverMsg ??
              'The server took too long to process the request. Please try again.',
          statusCode: code,
        );
      case 413:
        return ApiException(
          ApiErrorKind.unknown,
          serverMsg ?? 'The file you tried to upload is too large.',
          statusCode: code,
        );
      case 429:
        return ApiException(
          ApiErrorKind.server,
          serverMsg ??
              'Too many requests in a short time. Please wait a minute and try again.',
          statusCode: code,
        );
      case 500:
        return ApiException(
          ApiErrorKind.server,
          serverMsg ??
              'The TCB server hit an unexpected error. Please try again — if it keeps happening, contact TCB Infotech.',
          statusCode: code,
        );
      case 502:
        // Bad Gateway: the proxy (Cloudflare / Nginx) reached us but could
        // not reach the origin. Usually means the Frappe bench is down or
        // the Cloudflare tunnel is disconnected.
        return ApiException(
          ApiErrorKind.server,
          serverMsg ??
              "Can't reach the TCB server right now. The server may be temporarily down. Try again in a few minutes — contact TCB Infotech if this keeps happening.",
          statusCode: code,
        );
      case 503:
        return ApiException(
          ApiErrorKind.server,
          serverMsg ??
              'The TCB server is temporarily unavailable, likely for maintenance. Please try again shortly.',
          statusCode: code,
        );
      case 504:
        return ApiException(
          ApiErrorKind.timeout,
          serverMsg ??
              'The TCB server is taking too long to respond. Please try again in a moment.',
          statusCode: code,
        );
      default:
        if (code >= 500) {
          return ApiException(
            ApiErrorKind.server,
            serverMsg ??
                'The TCB server returned an error (HTTP $code). Please try again — if it keeps happening, contact TCB Infotech.',
            statusCode: code,
          );
        }
        if (code >= 400) {
          return ApiException(
            ApiErrorKind.unknown,
            serverMsg ?? 'Request failed (HTTP $code). Please try again.',
            statusCode: code,
          );
        }
        return ApiException(
          ApiErrorKind.unknown,
          serverMsg ?? 'Unexpected response from the server. Please try again.',
          statusCode: code,
        );
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
          return "You don't have permission to view this record.";
        }
        if (excType.contains('DoesNotExistError')) {
          return 'This record no longer exists.';
        }
        if (excType.contains('AuthenticationError')) {
          return 'Your session has expired. Please sign in again.';
        }
        if (excType.contains('ValidationError')) {
          // The validation message itself is usually in `_server_messages`,
          // already handled above. If we got here without one, give a generic.
          return 'The data you entered is not valid. Please check the form.';
        }
        if (excType.contains('RateLimitExceededError')) {
          return 'Too many requests in a short time. Please wait a minute and try again.';
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
