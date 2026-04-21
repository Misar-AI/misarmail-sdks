import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:misar_mail/misar_mail.dart';
import 'package:test/test.dart';

MisarMailClient _makeClient(
  http.Client mock, {
  int maxRetries = 1,
}) =>
    MisarMailClient(
      'test-key',
      baseUrl: 'https://mail.misar.io/api/v1',
      maxRetries: maxRetries,
      httpClient: mock,
    );

http.Response _jsonResp(int status, Map<String, dynamic> body) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

void main() {
  group('MisarMailClient', () {
    test('sendEmail sends POST and returns response', () async {
      final mock = MockClient((_) async => _jsonResp(200, {'id': 'msg1', 'status': 'queued'}));
      final client = _makeClient(mock);
      final result = await client.sendEmail({
        'to': 'a@b.com',
        'subject': 'Hi',
        'html': '<p>Hi</p>',
      });
      expect(result['id'], equals('msg1'));
      expect(result['status'], equals('queued'));
    });

    test('contactsList returns list response', () async {
      final mock = MockClient((_) async => _jsonResp(200, {'contacts': [], 'total': 0}));
      final client = _makeClient(mock);
      final result = await client.contactsList();
      expect(result['total'], equals(0));
    });

    test('campaignsList returns campaigns', () async {
      final mock = MockClient((_) async => _jsonResp(200, {'campaigns': []}));
      final client = _makeClient(mock);
      final result = await client.campaignsList();
      expect(result, containsPair('campaigns', isA<List>()));
    });

    test('analyticsGet returns analytics', () async {
      final mock = MockClient(
        (_) async => _jsonResp(200, {'campaign_id': 'c1', 'opens': 10}),
      );
      final client = _makeClient(mock);
      final result = await client.analyticsGet('c1');
      expect(result['opens'], equals(10));
    });

    test('validateEmail returns validation result', () async {
      final mock = MockClient(
        (_) async => _jsonResp(200, {'valid': true, 'email': 'a@b.com'}),
      );
      final client = _makeClient(mock);
      final result = await client.validateEmail('a@b.com');
      expect(result['valid'], isTrue);
    });

    test('throws MisarMailError on 401', () async {
      final mock = MockClient((_) async => _jsonResp(401, {'error': 'Unauthorized'}));
      final client = _makeClient(mock);
      expect(
        () => client.sendEmail({}),
        throwsA(
          isA<MisarMailError>().having((e) => e.status, 'status', 401),
        ),
      );
    });

    test('retries on 503 and succeeds', () async {
      var calls = 0;
      final mock = MockClient((_) async {
        calls++;
        if (calls == 1) return _jsonResp(503, {'error': 'down'});
        return _jsonResp(200, {'id': 'msg2'});
      });
      final client = _makeClient(mock, maxRetries: 2);
      final result = await client.sendEmail({});
      expect(result['id'], equals('msg2'));
      expect(calls, equals(2));
    });
  });
}
