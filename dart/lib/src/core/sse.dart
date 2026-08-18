import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../errors.dart';

const _done = '[DONE]';

/// Server-Sent Events client for the MisarMail streaming endpoints.
///
/// Both streams frame events as `data: <json>` and close with the sentinel
/// `data: [DONE]`. One of the two is a POST, so this drives the stream off a
/// streamed request rather than an EventSource-style helper.
Stream<Map<String, dynamic>> streamSse(
  String url,
  String apiKey, {
  String method = 'GET',
  Object? body,
  http.Client? httpClient,
}) async* {
  final client = httpClient ?? http.Client();

  try {
    final request = http.Request(method, Uri.parse(url))
      ..headers['Authorization'] = 'Bearer $apiKey'
      ..headers['Accept'] = 'text/event-stream';

    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    final response = await client.send(request);

    if (response.statusCode >= 400) {
      // Errors arrive as a normal JSON body, not as an SSE frame.
      final raw = await response.stream.bytesToString();
      Map<String, dynamic> data = const {};
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) data = decoded;
      } on FormatException {
        // Leave data empty; the status carries the meaning.
      }
      throw MisarMailError(
        response.statusCode,
        (data['error'] ?? 'HTTP ${response.statusCode}').toString(),
        (data['error_type'] ?? 'api_error').toString(),
        data,
      );
    }

    final lines = response.stream.transform(utf8.decoder).transform(const LineSplitter());

    await for (final line in lines) {
      if (!line.startsWith('data:')) continue;

      final payload = line.substring(5).trim();
      if (payload == _done) return;
      if (payload.isEmpty) continue;

      try {
        final decoded = jsonDecode(payload);
        yield decoded is Map<String, dynamic> ? decoded : {'value': decoded};
      } on FormatException {
        // One malformed frame should not discard everything already streamed.
        yield {'raw': payload};
      }
    }
  } finally {
    if (httpClient == null) client.close();
  }
}
