import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:misar_mail_flutter/misar_mail_flutter.dart';

import 'client_test.mocks.dart';

@GenerateMocks([http.Client, SecureKeyStore])
void main() {
  late MockClient mockHttp;
  late MisarMailClient client;

  setUp(() {
    mockHttp = MockClient();
    client = MisarMailClient(
      apiKey: 'msk_test',
      httpClient: mockHttp,
    );
  });

  http.Response _ok(Map<String, dynamic> body) =>
      http.Response(jsonEncode(body), 200);

  http.Response _err(int status, String msg) =>
      http.Response(jsonEncode({'error': msg}), status);

  // ---- sendEmail ------------------------------------------------------------

  test('sendEmail POSTs /send and returns body', () async {
    when(mockHttp.post(any, headers: anyNamed('headers'), body: anyNamed('body')))
        .thenAnswer((_) async => _ok({'id': 'msg_1'}));

    final res = await client.sendEmail({'to': 'a@b.com', 'subject': 'Hi'});
    expect(res['id'], 'msg_1');
  });

  // ---- contactsList ---------------------------------------------------------

  test('contactsList GETs /contacts', () async {
    when(mockHttp.get(any, headers: anyNamed('headers')))
        .thenAnswer((_) async => _ok({'contacts': []}));

    final res = await client.contactsList();
    expect(res.containsKey('contacts'), isTrue);
  });

  // ---- contactsCreate -------------------------------------------------------

  test('contactsCreate POSTs /contacts', () async {
    when(mockHttp.post(any, headers: anyNamed('headers'), body: anyNamed('body')))
        .thenAnswer((_) async => _ok({'id': 'cid_1'}));

    final res = await client.contactsCreate({'email': 'x@y.com'});
    expect(res['id'], 'cid_1');
  });

  // ---- campaignsList --------------------------------------------------------

  test('campaignsList GETs /campaigns', () async {
    when(mockHttp.get(any, headers: anyNamed('headers')))
        .thenAnswer((_) async => _ok({'campaigns': []}));

    final res = await client.campaignsList();
    expect(res.containsKey('campaigns'), isTrue);
  });

  // ---- campaignsCreate ------------------------------------------------------

  test('campaignsCreate POSTs /campaigns', () async {
    when(mockHttp.post(any, headers: anyNamed('headers'), body: anyNamed('body')))
        .thenAnswer((_) async => _ok({'id': 'camp_1'}));

    final res = await client.campaignsCreate({'name': 'Spring'});
    expect(res['id'], 'camp_1');
  });

  // ---- analyticsGet ---------------------------------------------------------

  test('analyticsGet GETs /analytics/{id}', () async {
    when(mockHttp.get(any, headers: anyNamed('headers')))
        .thenAnswer((_) async => _ok({'opens': 42}));

    final res = await client.analyticsGet('camp_1');
    expect(res['opens'], 42);

    final captured = verify(mockHttp.get(captureAny, headers: anyNamed('headers'))).captured;
    expect((captured.first as Uri).path, contains('/analytics/camp_1'));
  });

  // ---- validateEmail --------------------------------------------------------

  test('validateEmail POSTs /validate with email field', () async {
    when(mockHttp.post(any, headers: anyNamed('headers'), body: anyNamed('body')))
        .thenAnswer((_) async => _ok({'valid': true}));

    final res = await client.validateEmail('test@misar.io');
    expect(res['valid'], isTrue);

    final captured = verify(mockHttp.post(
      captureAny,
      headers: anyNamed('headers'),
      body: captureAnyNamed('body'),
    )).captured;
    final sentBody = jsonDecode(captured[1] as String) as Map<String, dynamic>;
    expect(sentBody['email'], 'test@misar.io');
  });

  // ---- keysList -------------------------------------------------------------

  test('keysList GETs /keys', () async {
    when(mockHttp.get(any, headers: anyNamed('headers')))
        .thenAnswer((_) async => _ok({'keys': []}));

    final res = await client.keysList();
    expect(res.containsKey('keys'), isTrue);
  });

  // ---- abTestsList ----------------------------------------------------------

  test('abTestsList GETs /ab-tests', () async {
    when(mockHttp.get(any, headers: anyNamed('headers')))
        .thenAnswer((_) async => _ok({'tests': []}));

    final res = await client.abTestsList();
    expect(res.containsKey('tests'), isTrue);
  });

  // ---- sandboxList ----------------------------------------------------------

  test('sandboxList GETs /sandbox', () async {
    when(mockHttp.get(any, headers: anyNamed('headers')))
        .thenAnswer((_) async => _ok({'messages': []}));

    final res = await client.sandboxList();
    expect(res.containsKey('messages'), isTrue);
  });

  // ---- trackEvent -----------------------------------------------------------

  test('trackEvent POSTs /track/event', () async {
    when(mockHttp.post(any, headers: anyNamed('headers'), body: anyNamed('body')))
        .thenAnswer((_) async => _ok({'ok': true}));

    final res = await client.trackEvent({'event': 'open'});
    expect(res['ok'], isTrue);
  });

  // ---- trackPurchase --------------------------------------------------------

  test('trackPurchase POSTs /track/purchase', () async {
    when(mockHttp.post(any, headers: anyNamed('headers'), body: anyNamed('body')))
        .thenAnswer((_) async => _ok({'ok': true}));

    final res = await client.trackPurchase({'amount': 99});
    expect(res['ok'], isTrue);
  });

  // ---- inboundList ----------------------------------------------------------

  test('inboundList GETs /inbound', () async {
    when(mockHttp.get(any, headers: anyNamed('headers')))
        .thenAnswer((_) async => _ok({'inbound': []}));

    final res = await client.inboundList();
    expect(res.containsKey('inbound'), isTrue);
  });

  // ---- templatesList --------------------------------------------------------

  test('templatesList GETs /templates', () async {
    when(mockHttp.get(any, headers: anyNamed('headers')))
        .thenAnswer((_) async => _ok({'templates': []}));

    final res = await client.templatesList();
    expect(res.containsKey('templates'), isTrue);
  });

  // ---- templatesRender ------------------------------------------------------

  test('templatesRender POSTs /templates/{id}/render with variables', () async {
    when(mockHttp.post(any, headers: anyNamed('headers'), body: anyNamed('body')))
        .thenAnswer((_) async => _ok({'html': '<p>Hello</p>'}));

    final res = await client.templatesRender('tmpl_1', {'name': 'Alice'});
    expect(res['html'], '<p>Hello</p>');

    final captured = verify(mockHttp.post(
      captureAny,
      headers: anyNamed('headers'),
      body: captureAnyNamed('body'),
    )).captured;
    expect((captured[0] as Uri).path, contains('/templates/tmpl_1/render'));
    final sentBody = jsonDecode(captured[1] as String) as Map<String, dynamic>;
    expect((sentBody['variables'] as Map)['name'], 'Alice');
  });

  // ---- error handling -------------------------------------------------------

  test('throws MisarMailException on 4xx', () async {
    when(mockHttp.get(any, headers: anyNamed('headers')))
        .thenAnswer((_) async => _err(401, 'unauthorized'));

    expect(
      () => client.contactsList(),
      throwsA(isA<MisarMailException>().having((e) => e.statusCode, 'statusCode', 401)),
    );
  });

  test('retries on 429 then throws on repeated failure', () async {
    when(mockHttp.get(any, headers: anyNamed('headers')))
        .thenAnswer((_) async => _err(429, 'rate limited'));

    final clientFast = MisarMailClient(
      apiKey: 'msk_test',
      maxRetries: 2,
      httpClient: mockHttp,
    );

    await expectLater(
      clientFast.contactsList(),
      throwsA(isA<MisarMailException>().having((e) => e.statusCode, 'statusCode', 429)),
    );

    verify(mockHttp.get(any, headers: anyNamed('headers'))).called(2);
  });

  test('retries on 503 and succeeds on second attempt', () async {
    var calls = 0;
    when(mockHttp.get(any, headers: anyNamed('headers'))).thenAnswer((_) async {
      calls++;
      if (calls == 1) return _err(503, 'unavailable');
      return _ok({'contacts': []});
    });

    final res = await client.contactsList();
    expect(res.containsKey('contacts'), isTrue);
    expect(calls, 2);
  });

  // ---- Authorization header -------------------------------------------------

  test('sends correct Authorization header', () async {
    when(mockHttp.get(any, headers: anyNamed('headers')))
        .thenAnswer((_) async => _ok({}));

    await client.keysList();

    final captured = verify(mockHttp.get(any, headers: captureAnyNamed('headers'))).captured;
    final headers = captured.first as Map<String, String>;
    expect(headers['Authorization'], 'Bearer msk_test');
  });

  // ---- SecureKeyStore -------------------------------------------------------

  test('withSecureStorage throws StateError when no key stored', () async {
    final mockStore = MockSecureKeyStore();
    when(mockStore.loadApiKey()).thenAnswer((_) async => null);

    await expectLater(
      MisarMailClient.withSecureStorage(keyStore: mockStore),
      throwsA(isA<StateError>()),
    );
  });

  test('withSecureStorage creates client with stored key', () async {
    final mockStore = MockSecureKeyStore();
    when(mockStore.loadApiKey()).thenAnswer((_) async => 'msk_stored');
    when(mockHttp.get(any, headers: anyNamed('headers')))
        .thenAnswer((_) async => _ok({'keys': []}));

    final secureClient = await MisarMailClient.withSecureStorage(
      keyStore: mockStore,
      httpClient: mockHttp,
    );

    await secureClient.keysList();

    final captured = verify(mockHttp.get(any, headers: captureAnyNamed('headers'))).captured;
    final headers = captured.first as Map<String, String>;
    expect(headers['Authorization'], 'Bearer msk_stored');
  });
}
