import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:misarmail_flutter/misarmail_flutter.dart';

MisarMailClient _client(http.Client mock, {int maxRetries = 1}) =>
    MisarMailClient(
      apiKey: 'mmk_test',
      baseUrl: 'https://api.misar.io/mail/v1',
      maxRetries: maxRetries,
      httpClient: mock,
    );

/// Streams the given pieces as one `text/event-stream` body, so a frame
/// boundary can land mid-chunk — where buffering bugs show up.
MockClient _sseMock(List<String> pieces, {void Function(http.BaseRequest)? onRequest}) =>
    MockClient.streaming((req, bodyStream) async {
      onRequest?.call(req);
      // Each piece is a separate chunk, so a frame boundary can straddle two
      // reads. A StreamController would deadlock here: awaiting close() before
      // anything listens never completes.
      return http.StreamedResponse(
        Stream.fromIterable(pieces.map(utf8.encode)),
        200,
        headers: {'content-type': 'text/event-stream'},
      );
    });

void main() {
  group('rest', () {
    test('email.send() returns the parsed body', () async {
      final mock = MockClient((req) async =>
          http.Response('{"success":true,"message_id":"msg_123"}', 200,
              headers: {'content-type': 'application/json'}));

      final result = await _client(mock).email.send({'from': 'a@b.com'});

      expect(result['success'], isTrue);
      expect(result['message_id'], 'msg_123');
    });

    test('contacts.list() returns data', () async {
      final mock = MockClient((req) async => http.Response(
          '{"data":[{"id":"c1","email":"a@b.com"}],"total":1}', 200,
          headers: {'content-type': 'application/json'}));

      final result = await _client(mock).contacts.list();

      expect(result['data'][0]['email'], 'a@b.com');
    });

    test('plan.get() reports the subscription behind the key', () async {
      final mock = MockClient((req) async => http.Response(
          '{"plan":{"slug":"pro"},"limits":{"emails_per_month":50000}}', 200,
          headers: {'content-type': 'application/json'}));

      final result = await _client(mock).plan.get();

      expect(result['plan']['slug'], 'pro');
      expect(result['limits']['emails_per_month'], 50000);
    });

    test('a 401 raises with the status', () async {
      final mock = MockClient((req) async =>
          http.Response('{"error":"unauthorized"}', 401,
              headers: {'content-type': 'application/json'}));

      expect(
        () => _client(mock).contacts.list(),
        throwsA(isA<MisarMailException>()
            .having((e) => e.statusCode, 'statusCode', 401)),
      );
    });

    test('retries a 503 then succeeds', () async {
      var attempts = 0;
      final mock = MockClient((req) async {
        attempts++;
        if (attempts < 3) {
          return http.Response('{"error":"unavailable"}', 503);
        }
        return http.Response('{"data":[{"id":"t1"}]}', 200,
            headers: {'content-type': 'application/json'});
      });

      final result = await _client(mock, maxRetries: 3).templates.list();

      expect(result['data'][0]['id'], 't1');
      expect(attempts, 3);
    });
  });

  group('plan limits', () {
    test('a spent allowance raises PlanLimit and is not retried', () async {
      var attempts = 0;
      final mock = MockClient((req) async {
        attempts++;
        return http.Response(
          '{"code":"plan_limit_exceeded","error":"monthly campaign allowance spent",'
          '"upgrade":{"feature":"campaigns","currentPlanSlug":"starter",'
          '"urls":{"pricing":"https://misarmail.com/pricing"}}}',
          429,
          headers: {
            'content-type': 'application/json',
            'x-misar-plan': 'starter',
            'retry-after': '3600',
          },
        );
      });

      // maxRetries 3, so a plain retryable 429 would have been retried twice more.
      await expectLater(
        () => _client(mock, maxRetries: 3).campaigns.create({'name': 'Blast'}),
        throwsA(isA<MisarMailPlanLimitException>()
            .having((e) => e.statusCode, 'statusCode', 429)
            .having((e) => e.plan, 'plan', 'starter')
            .having((e) => e.feature, 'feature', 'campaigns')
            .having((e) => e.retryAfter, 'retryAfter', 3600)
            .having((e) => e.upgradeUrl, 'upgradeUrl',
                'https://misarmail.com/pricing')),
      );

      // A spent allowance cannot be fixed by retrying.
      expect(attempts, 1);
    });
  });

  group('streaming', () {
    test('generateEmail() yields each frame', () async {
      // The boundary between "Hel" and "lo" is split across two chunks.
      final mock = _sseMock([
        'data: {"delta":"Hel"}\n',
        '\ndata: {"delta":"lo"}\n\n',
        ': keepalive\n\n',
        'data: {"delta":"!"}\n\n',
        'data: [DONE]\n\n',
      ]);

      final deltas = await _client(mock)
          .streaming
          .generateEmail({'prompt': 'hi'})
          .map((e) => e.data['delta'] as String)
          .toList();

      expect(deltas, ['Hel', 'lo', '!']);
    });

    test('the stream stops at the [DONE] sentinel', () async {
      final mock = _sseMock([
        'data: {"sent":1}\n\n',
        'data: [DONE]\n\n',
        'data: {"sent":999}\n\n',
      ]);

      final seen =
          await _client(mock).streaming.campaignSend('camp1').toList();

      // Anything after the sentinel must never be delivered.
      expect(seen.length, 1);
      expect(seen.first.data['sent'], 1);
    });

    test('the stream uses the unversioned api base', () async {
      late http.BaseRequest seen;
      final mock = _sseMock(['data: [DONE]\n\n'], onRequest: (r) => seen = r);

      await _client(mock).streaming.campaignSend('camp1').toList();

      // Both SSE routes live outside /v1, so the path must not carry it.
      expect(seen.url.toString(),
          'https://api.misar.io/mail/campaigns/camp1/send-stream');
    });

    test('a refused stream raises PlanLimit before any frame', () async {
      final mock = MockClient.streaming((req, bodyStream) async =>
          http.StreamedResponse(
            Stream.value(utf8.encode(
                '{"code":"plan_limit_exceeded","error":"streaming is not on your plan",'
                '"upgrade":{"feature":"campaign_streaming",'
                '"urls":{"pricing":"https://misarmail.com/pricing"}}}')),
            402,
            headers: {
              'content-type': 'application/json',
              'x-misar-plan': 'free',
            },
          ));

      expect(
        () => _client(mock).streaming.campaignSend('locked').toList(),
        throwsA(isA<MisarMailPlanLimitException>()
            .having((e) => e.statusCode, 'statusCode', 402)
            .having((e) => e.plan, 'plan', 'free')
            .having((e) => e.feature, 'feature', 'campaign_streaming')),
      );
    });
  });
}
