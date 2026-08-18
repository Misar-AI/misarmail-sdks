import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../exceptions.dart';

/// HTTP transport shared by the generated resource layer.
///
/// Everything the SDK does goes through one of three transports — HTTP for
/// REST, SSE for streaming, WebSocket for push — and all three authenticate the
/// same way: the account API key, sent as a bearer token. There is no second
/// credential path. What a key may do, and how much of it, is decided
/// server-side from the subscription behind that key.
class Transport {
  Transport(
    this.apiKey, {
    String baseUrl = 'https://api.misar.io/mail',
    this.maxRetries = 3,
    this.timeout = const Duration(seconds: 30),
    http.Client? httpClient,
  })  : baseUrl = baseUrl.endsWith('/')
            ? baseUrl.substring(0, baseUrl.length - 1)
            : baseUrl,
        _http = httpClient ?? http.Client() {
    if (apiKey.isEmpty) {
      throw ArgumentError(
        'A MisarMail API key is required. '
        'Create one at https://mail.misar.io/settings/api-keys.',
      );
    }
  }

  static const _retryableStatuses = {429, 500, 502, 503, 504};

  final String apiKey;
  final String baseUrl;
  final int maxRetries;
  final Duration timeout;
  final http.Client _http;

  Map<String, String> get headers => {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      };

  /// Issue a request against a manifest path and decode the JSON body.
  Future<Map<String, dynamic>> request(
    String method,
    String path, [
    Object? body,
  ]) async {
    final uri = Uri.parse('$baseUrl$path');

    for (var attempt = 0;; attempt++) {
      http.Response response;
      try {
        final request = http.Request(method, uri)..headers.addAll(headers);
        if (body != null) request.body = jsonEncode(body);

        final streamed = await _http.send(request).timeout(timeout);
        response = await http.Response.fromStream(streamed);
      } catch (error) {
        if (attempt < maxRetries - 1) {
          await Future<void>.delayed(_backoff(attempt, null));
          continue;
        }
        throw MisarMailNetworkError(error.toString());
      }

      if (_retryableStatuses.contains(response.statusCode) && attempt < maxRetries - 1) {
        await Future<void>.delayed(_backoff(attempt, response));
        continue;
      }

      return _decode(response);
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> data = const {};
    if (response.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) data = decoded;
      } on FormatException {
        // A non-JSON error body is still an error; fall through with {}.
      }
    }

    if (response.statusCode >= 400) {
      throw MisarMailError(
        response.statusCode,
        (data['error'] ?? data['message'] ?? response.reasonPhrase ?? 'HTTP error').toString(),
        (data['error_type'] ?? 'api_error').toString(),
        data,
      );
    }

    return data;
  }

  /// Exponential backoff, but honour Retry-After when the server sends one: on
  /// a 429 the server knows when the window reopens, and guessing wastes the
  /// caller's remaining budget.
  Duration _backoff(int attempt, http.Response? response) {
    final header = response?.headers['retry-after'];
    if (header != null) {
      final seconds = int.tryParse(header);
      if (seconds != null && seconds >= 0) {
        return Duration(seconds: seconds > 60 ? 60 : seconds);
      }
    }
    return Duration(milliseconds: 200 * (1 << attempt));
  }

  void close() => _http.close();
}
