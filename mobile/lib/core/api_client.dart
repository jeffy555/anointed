import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'config.dart';
import 'device_context.dart';

/// Backend error, carrying the stable `code` the FastAPI error envelope returns
/// (see backend/app/core/errors.py) so screens can branch on the code instead of
/// pattern-matching a message.
class ApiException implements Exception {
  ApiException({
    required this.statusCode,
    required this.code,
    required this.message,
    this.fields = const <String, String>{},
    this.retryAfter,
    this.extra = const <String, dynamic>{},
  });

  /// Used when the request never reached the server.
  factory ApiException.offline() => ApiException(
        statusCode: 0,
        code: 'offline',
        message: 'No internet connection.',
      );

  factory ApiException.timeout() => ApiException(
        statusCode: 0,
        code: 'timeout',
        message: 'The server took too long to respond.',
      );

  final int statusCode;
  final String code;
  final String message;
  final Map<String, String> fields;
  final Duration? retryAfter;
  final Map<String, dynamic> extra;

  bool get isOffline => code == 'offline' || code == 'timeout';
  bool get isUnauthorized => statusCode == 401;
  bool get isConsentBlocked =>
      code == 'consent_pending' ||
      code == 'consent_expired' ||
      code == 'consent_denied' ||
      code == 'consent_abandoned' ||
      code == 'consent_required';
  bool get isProfileIncomplete => code == 'profile_incomplete';

  @override
  String toString() => 'ApiException($statusCode, $code): $message';
}

/// Thin JSON client over the FastAPI backend.
///
/// Owns three cross-cutting concerns so no call site repeats them: the auth
/// header, the analytics/abuse `X-*` envelope headers, and error normalisation.
class ApiClient {
  ApiClient({
    required DeviceContext deviceContext,
    http.Client? httpClient,
    String? baseUrl,
  })  : _device = deviceContext,
        _http = httpClient ?? http.Client(),
        _baseUrl = baseUrl ?? AppConfig.apiBaseUrl;

  final DeviceContext _device;
  final http.Client _http;
  final String _baseUrl;

  String? _sessionToken;

  /// Invoked when the server rejects the session token. The session controller
  /// uses it to drop the stored token and route back to Welcome.
  void Function()? onUnauthorized;

  String get baseUrl => _baseUrl;

  bool get hasSession => _sessionToken != null && _sessionToken!.isNotEmpty;

  void setSessionToken(String? token) => _sessionToken = token;

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final http.Response response = await _send(
      'GET',
      path,
      query: query,
    );
    return _decodeObject(response);
  }

  Future<List<dynamic>> getJsonList(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final http.Response response = await _send('GET', path, query: query);
    final Object? decoded = _decodeBody(response);
    if (decoded is List) return decoded;
    return const <dynamic>[];
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) async {
    final http.Response response =
        await _send('POST', path, body: body, query: query);
    return _decodeObject(response);
  }

  Future<Map<String, dynamic>> patchJson(
    String path, {
    Object? body,
  }) async {
    final http.Response response = await _send('PATCH', path, body: body);
    return _decodeObject(response);
  }

  /// Raw byte fetch for the practice content pack, which is a gzipped blob and a
  /// 204 rather than JSON (see backend/app/routers/content.py).
  Future<ApiBytes> getBytes(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final http.Response response = await _send('GET', path, query: query);
    if (response.statusCode == 204) {
      return ApiBytes(statusCode: 204, bytes: const <int>[], headers: response.headers);
    }
    if (response.statusCode >= 400) {
      throw _errorFor(response);
    }
    return ApiBytes(
      statusCode: response.statusCode,
      bytes: response.bodyBytes,
      headers: response.headers,
    );
  }

  Future<http.Response> _send(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) async {
    final Uri uri = _uri(path, query);
    final Map<String, String> headers = <String, String>{
      'Accept': 'application/json',
      ..._device.headers,
      if (body != null) 'Content-Type': 'application/json',
      if (hasSession) 'Authorization': 'Bearer $_sessionToken',
    };

    try {
      final http.Request request = http.Request(method, uri)..headers.addAll(headers);
      if (body != null) {
        request.body = jsonEncode(body);
      }
      final http.StreamedResponse streamed =
          await _http.send(request).timeout(AppConfig.apiTimeout);
      final http.Response response = await http.Response.fromStream(streamed);

      if (response.statusCode == 401) {
        onUnauthorized?.call();
      }
      return response;
    } on TimeoutException {
      throw ApiException.timeout();
    } on SocketException {
      throw ApiException.offline();
    } on http.ClientException {
      throw ApiException.offline();
    } on HandshakeException {
      throw ApiException.offline();
    }
  }

  Uri _uri(String path, Map<String, dynamic>? query) {
    final Uri base = Uri.parse('$_baseUrl$path');
    if (query == null || query.isEmpty) return base;
    final Map<String, String> encoded = <String, String>{};
    query.forEach((String key, Object? value) {
      if (value != null) encoded[key] = '$value';
    });
    return base.replace(queryParameters: <String, String>{
      ...base.queryParameters,
      ...encoded,
    });
  }

  Map<String, dynamic> _decodeObject(http.Response response) {
    if (response.statusCode >= 400) {
      throw _errorFor(response);
    }
    final Object? decoded = _decodeBody(response);
    if (decoded is Map<String, dynamic>) return decoded;
    return <String, dynamic>{};
  }

  Object? _decodeBody(http.Response response) {
    if (response.bodyBytes.isEmpty) return null;
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      return null;
    }
  }

  ApiException _errorFor(http.Response response) {
    final Object? decoded = _decodeBody(response);
    final Map<String, dynamic> payload =
        decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};

    final Map<String, String> fields = <String, String>{};
    final Object? rawFields = payload['fields'];
    if (rawFields is List) {
      for (final Object? item in rawFields) {
        if (item is Map && item['field'] != null) {
          fields['${item['field']}'] = '${item['error'] ?? ''}';
        }
      }
    }

    final String? retryHeader = response.headers['retry-after'];
    final int? retrySeconds = retryHeader == null ? null : int.tryParse(retryHeader);

    return ApiException(
      statusCode: response.statusCode,
      code: '${payload['code'] ?? _fallbackCode(response.statusCode)}',
      message: '${payload['message'] ?? 'Something went wrong. Please try again.'}',
      fields: fields,
      retryAfter: retrySeconds == null ? null : Duration(seconds: retrySeconds),
      extra: payload,
    );
  }

  String _fallbackCode(int statusCode) {
    switch (statusCode) {
      case 400:
        return 'bad_request';
      case 401:
        return 'not_authenticated';
      case 403:
        return 'forbidden';
      case 404:
        return 'not_found';
      case 409:
        return 'conflict';
      case 429:
        return 'rate_limited';
      default:
        return 'error';
    }
  }

  void dispose() => _http.close();
}

class ApiBytes {
  const ApiBytes({
    required this.statusCode,
    required this.bytes,
    required this.headers,
  });

  final int statusCode;
  final List<int> bytes;
  final Map<String, String> headers;

  bool get isNoContent => statusCode == 204;
}
