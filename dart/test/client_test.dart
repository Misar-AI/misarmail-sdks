import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:misarmail/misarmail.dart';
import 'package:test/test.dart';

MisarMailClient _client(http.Client mock, {int maxRetries = 3}) =>
    MisarMailClient(
      apiKey: 'mmk_test',
      baseUrl: 'https://api.misar.io/mail/v1',
      maxRetries: maxRetries,
      httpClient: mock,
    );

void main() {
  group('plan', () {
    test('get() returns the plan, allowances and per-feature usage', () async {
      late http.Request seen;
      final mock = MockClient((req) async {
        seen = req;
        return http.Response(
          jsonEncode({
            'plan': {'slug': 'starter', 'name': 'Starter'},
            'sending': {'emails_per_day': 500, 'emails_per_month': 10000},
            'usage': [
              {'feature': 'emails', 'used': 120, 'limit': 500, 'remaining': 380}
            ],
            'upgrade': null,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final out = await _client(mock).plan.get();

      expect(seen.url.path, endsWith('/plan'));
      expect(seen.headers['Authorization'], equals('Bearer mmk_test'));
      expect(out['plan']['slug'], equals('starter'));
      expect(out['usage'][0]['used'], equals(120));
      expect(out['upgrade'], isNull);
    });
  });

  group('plan limits', () {
    // A spent allowance answers 429 — identical by status to a rate limit — so
    // the client must tell them apart by body and not retry the refusal.
    test('a plan refusal is typed and not retried', () async {
      var attempts = 0;
      final mock = MockClient((req) async {
        attempts++;
        return http.Response(
          jsonEncode({
            'error': 'Monthly send allowance spent.',
            'code': 'plan_limit_exceeded',
            'upgrade': {'feature': 'emails', 'currentPlanSlug': 'starter'},
          }),
          429,
          headers: {
            'content-type': 'application/json',
            'x-misar-plan': 'starter',
            'x-misar-upgrade-url': 'https://misarmail.com/pricing',
            'retry-after': '600',
          },
        );
      });

      await expectLater(
        _client(mock).plan.get(),
        throwsA(isA<MisarMailPlanLimitError>()
            .having((e) => e.plan, 'plan', 'starter')
            .having((e) => e.upgradeUrl, 'upgradeUrl',
                'https://misarmail.com/pricing')
            .having((e) => e.retryAfter, 'retryAfter', 600)
            .having((e) => e.feature, 'feature', 'emails')),
      );
      expect(attempts, equals(1),
          reason: 'a plan refusal must not burn the retry budget');
    });

    test('a plain rate-limit 429 is still retried', () async {
      var attempts = 0;
      final mock = MockClient((req) async {
        attempts++;
        if (attempts == 1) {
          return http.Response(jsonEncode({'error': 'Rate limit exceeded'}), 429,
              headers: {'content-type': 'application/json'});
        }
        return http.Response(
          jsonEncode({
            'plan': {'slug': 'starter', 'name': 'Starter'}
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final out = await _client(mock).plan.get();
      expect(attempts, equals(2));
      expect(out['plan']['slug'], equals('starter'));
    });
  });

  test('401 surfaces as MisarMailError', () async {
    final mock = MockClient((req) async => http.Response(
          jsonEncode({'error': 'Invalid or missing API key'}),
          401,
          headers: {'content-type': 'application/json'},
        ));

    await expectLater(
      _client(mock).plan.get(),
      throwsA(isA<MisarMailError>().having((e) => e.status, 'status', 401)),
    );
  });
}
