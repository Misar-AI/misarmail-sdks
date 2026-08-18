import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:misarmail/misarmail.dart';
import 'package:test/test.dart';

/// Serves a fixed SSE body, emitted as separate stream events so a frame can
/// straddle two reads.
MisarMailClient _client(List<String> chunks, {int status = 200}) {
  final mock = MockClient.streaming((request, bodyStream) async {
    if (status >= 400) {
      return http.StreamedResponse(
        Stream.value(utf8.encode(chunks.first)),
        status,
        headers: {'content-type': 'application/json'},
      );
    }
    return http.StreamedResponse(
      Stream.fromIterable(chunks.map(utf8.encode)),
      200,
      headers: {'content-type': 'text/event-stream'},
    );
  });
  return MisarMailClient(apiKey: 'mmk_test', httpClient: mock);
}

void main() {
  group('SSE frame parsing', () {
    test('yields frames and stops at the [DONE] sentinel', () async {
      final c = _client([
        'data: {"delta":"Hel","type":"body"}\n\n',
        'data: {"delta":"lo","type":"body"}\n\n',
        'data: {"done":true,"type":"body"}\n\n',
        'data: [DONE]\n\n',
        'data: {"delta":"after-done"}\n\n', // must never arrive
      ]);

      final seen = await c.streaming.generateEmail({'prompt': 'hi'}).toList();

      expect(seen.length, equals(3));
      expect(seen[0].data['delta'], equals('Hel'));
      expect(seen[1].data['delta'], equals('lo'));
      expect(seen[2].data['done'], isTrue);
    });

    test('reassembles frames split across chunk boundaries', () async {
      final c = _client(['data: {"del', 'ta":"x"}\n', '\ndata: [DONE]\n\n']);
      final seen = await c.streaming.generateEmail({'prompt': 'hi'}).toList();
      expect(seen.length, equals(1));
      expect(seen[0].data['delta'], equals('x'));
    });

    test('skips keepalives and tolerates CRLF', () async {
      final c = _client([
        ': keepalive\n\n',
        'data: {"delta":"a"}\r\n\r\n',
        ': keepalive\n\n',
        'data: [DONE]\r\n\r\n',
      ]);
      final seen = await c.streaming.generateEmail({'prompt': 'hi'}).toList();
      expect(seen.length, equals(1));
      expect(seen[0].data['delta'], equals('a'));
    });

    test('surfaces the server error frame', () async {
      final c = _client(
          ['data: {"error":"generation_failed"}\n\n', 'data: [DONE]\n\n']);
      final seen = await c.streaming.generateEmail({'prompt': 'hi'}).toList();
      expect(seen.single.data['error'], equals('generation_failed'));
    });
  });

  group('stream errors', () {
    test('401 throws MisarMailError', () async {
      final c = _client(['{"error":"Invalid or missing API key"}'], status: 401);
      await expectLater(
        c.streaming.generateEmail({'prompt': 'hi'}).toList(),
        throwsA(isA<MisarMailError>().having((e) => e.status, 'status', 401)),
      );
    });

    test('a plan refusal on open is typed', () async {
      final c = _client([
        '{"error":"spent","code":"plan_limit_exceeded","upgrade":{"feature":"ai"}}'
      ], status: 429);
      await expectLater(
        c.streaming.generateEmail({'prompt': 'hi'}).toList(),
        throwsA(isA<MisarMailPlanLimitError>()
            .having((e) => e.feature, 'feature', 'ai')),
      );
    });
  });
}
