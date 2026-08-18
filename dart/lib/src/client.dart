import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'errors.dart';

/// Returns the decoded body when it carries the API's plan-refusal marker,
/// otherwise null.
Map<String, dynamic>? _planLimitBody(String raw) {
  if (raw.isEmpty) return null;
  try {
    final d = jsonDecode(raw);
    if (d is Map<String, dynamic> &&
        (d['code'] == 'plan_limit_exceeded' ||
            d['error_type'] == 'plan_limit_exceeded' ||
            d['upgrade'] is Map)) {
      return d;
    }
  } catch (_) {}
  return null;
}

abstract class _Resource {
  final MisarMailClient _client;
  const _Resource(this._client);
}

String _deriveApiBase(String? baseUrl) {
  final b = (baseUrl ?? 'https://api.misar.io/mail/v1')
      .replaceAll(RegExp(r'/$'), '');
  final idx = b.lastIndexOf('/v1');
  return idx >= 0 ? b.substring(0, idx) : b;
}

class MisarMailClient {
  final String _apiKey;
  final String _baseUrl;
  final String _apiBase;
  final int _maxRetries;
  final http.Client _httpClient;

  late final PlanResource plan;
  late final StreamingResource streaming;
  late final AiResource ai;
  late final CreditRatesResource creditRates;
  late final DeliverabilityResource deliverability;
  late final DmarcResource dmarc;
  late final EmailAccountsResource emailAccounts;
  late final EmailsResource emails;
  late final LandingPagesResource landingPages;
  late final MonetizationResource monetization;
  late final RevenueResource revenue;
  late final SegmentsResource segments;
  late final SubscriptionResource subscription;
  late final TeamMembersResource teamMembers;
  late final WalletResource wallet;
  late final WarmupResource warmup;
  late final EmailResource email;
  late final ContactsResource contacts;
  late final CampaignsResource campaigns;
  late final TemplatesResource templates;
  late final AutomationsResource automations;
  late final DomainsResource domains;
  late final DedicatedIpsResource dedicatedIps;
  late final AbTestsResource abTests;
  late final SandboxResource sandbox;
  late final InboundResource inbound;
  late final AnalyticsResource analytics;
  late final TrackResource track;
  late final KeysResource keys;
  late final ValidateResource validate;
  late final WebhooksResource webhooks;
  late final UsageResource usage;
  late final BillingResource billing;

  MisarMailClient({
    required String apiKey,
    String? baseUrl,
    int maxRetries = 3,
    http.Client? httpClient,
  })  : _apiKey = apiKey,
        _baseUrl = (baseUrl ?? 'https://api.misar.io/mail/v1')
            .replaceAll(RegExp(r'/$'), ''),
        _apiBase = _deriveApiBase(baseUrl),
        _maxRetries = maxRetries,
        _httpClient = httpClient ?? http.Client() {
    email = EmailResource(this);
    plan = PlanResource(this);
    streaming = StreamingResource(this);
    ai = AiResource(this);
    creditRates = CreditRatesResource(this);
    deliverability = DeliverabilityResource(this);
    dmarc = DmarcResource(this);
    emailAccounts = EmailAccountsResource(this);
    emails = EmailsResource(this);
    landingPages = LandingPagesResource(this);
    monetization = MonetizationResource(this);
    revenue = RevenueResource(this);
    segments = SegmentsResource(this);
    subscription = SubscriptionResource(this);
    teamMembers = TeamMembersResource(this);
    wallet = WalletResource(this);
    warmup = WarmupResource(this);
    contacts = ContactsResource(this);
    campaigns = CampaignsResource(this);
    templates = TemplatesResource(this);
    automations = AutomationsResource(this);
    domains = DomainsResource(this);
    dedicatedIps = DedicatedIpsResource(this);
    abTests = AbTestsResource(this);
    sandbox = SandboxResource(this);
    inbound = InboundResource(this);
    analytics = AnalyticsResource(this);
    track = TrackResource(this);
    keys = KeysResource(this);
    validate = ValidateResource(this);
    webhooks = WebhooksResource(this);
    usage = UsageResource(this);
    billing = BillingResource(this);
  }

  void close() => _httpClient.close();

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParams,
    bool useApiBase = false,
  }) async {
    final base = useApiBase ? _apiBase : _baseUrl;
    Uri uri = Uri.parse('$base$path');
    if (queryParams != null && queryParams.isNotEmpty) {
      uri = uri.replace(
        queryParameters: queryParams.map(
          (k, v) => MapEntry(k, v.toString()),
        ),
      );
    }
    final headers = {
      'Authorization': 'Bearer $_apiKey',
      'Content-Type': 'application/json',
    };

    int attempt = 0;
    while (true) {
      try {
        http.Response response;
        final encoded = body != null ? jsonEncode(body) : null;
        switch (method.toUpperCase()) {
          case 'GET':
            response = await _httpClient.get(uri, headers: headers);
            break;
          case 'POST':
            response = await _httpClient.post(uri, headers: headers, body: encoded);
            break;
          case 'PATCH':
            response = await _httpClient.patch(uri, headers: headers, body: encoded);
            break;
          case 'PUT':
            response = await _httpClient.put(uri, headers: headers, body: encoded);
            break;
          case 'DELETE':
            response = await _httpClient.delete(uri, headers: headers, body: encoded);
            break;
          default:
            throw MisarMailError(0, 'Unsupported HTTP method: $method');
        }

        final status = response.statusCode;

        if (status >= 200 && status < 300) {
          if (response.body.isEmpty) return {};
          return jsonDecode(response.body) as Map<String, dynamic>;
        }

        // A rate-limit 429 and a spent-allowance 429 are identical by status,
        // so the body decides. Only the first is worth retrying.
        final planLimit = _planLimitBody(response.body);
        if (planLimit != null) {
          throw MisarMailPlanLimitError.from(
              status, planLimit, response.headers);
        }

        if (const {429, 500, 502, 503, 504}.contains(status) &&
            attempt < _maxRetries - 1) {
          await Future<void>.delayed(
              Duration(milliseconds: 500 * (1 << attempt)));
          attempt++;
          continue;
        }

        Map<String, dynamic> errBody = {};
        try {
          errBody = jsonDecode(response.body) as Map<String, dynamic>;
        } catch (_) {}
        final message =
            (errBody['error'] as String?) ?? response.reasonPhrase ?? 'error';
        throw MisarMailError(status, message);
      } on MisarMailError {
        rethrow;
      } on SocketException catch (e) {
        throw MisarMailNetworkError(e.message);
      } catch (e) {
        if (attempt < _maxRetries - 1) {
          await Future<void>.delayed(
              Duration(milliseconds: 500 * (1 << attempt)));
          attempt++;
          continue;
        }
        throw MisarMailNetworkError(e.toString());
      }
    }
  }

  /// Opens an SSE connection and yields each frame as it arrives.
  ///
  /// Uses the API base, since both streaming routes sit outside `/v1`. Frames
  /// end at a blank line and may span several `data:` lines; the `[DONE]`
  /// sentinel ends the stream and is not yielded.
  ///
  /// Deliberately not retried: replaying a stream that failed mid-flight would
  /// duplicate whatever the caller already consumed.
  Stream<MisarMailStreamEvent> _sseStream(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async* {
    final request = http.Request(method, Uri.parse('$_apiBase$path'))
      ..headers.addAll({
        'Authorization': 'Bearer $_apiKey',
        'Accept': 'text/event-stream',
        'Content-Type': 'application/json',
      });
    if (body != null) request.body = jsonEncode(body);

    http.StreamedResponse response;
    try {
      response = await _httpClient.send(request);
    } on SocketException catch (e) {
      throw MisarMailNetworkError(e.message);
    } on http.ClientException catch (e) {
      throw MisarMailNetworkError(e.message);
    }

    if (response.statusCode >= 400) {
      final raw = await response.stream.bytesToString();
      final planLimit = _planLimitBody(raw);
      if (planLimit != null) {
        throw MisarMailPlanLimitError.from(
            response.statusCode, planLimit, response.headers);
      }
      String message = raw;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          message = (decoded['error'] as String?) ?? raw;
        }
      } catch (_) {}
      throw MisarMailError(
          response.statusCode, message.isEmpty ? 'stream error' : message);
    }

    var buffer = '';
    await for (final chunk in response.stream.transform(utf8.decoder)) {
      buffer += chunk;
      while (true) {
        final end = _sseFrameEnd(buffer);
        if (end == -1) break;
        final frame = buffer.substring(0, end);
        buffer = buffer.substring(end).replaceFirst(RegExp(r'^(\r?\n){1,2}'), '');
        final parsed = _parseSseFrame(frame);
        if (parsed == _sseDone) return;
        if (parsed != null) yield parsed as MisarMailStreamEvent;
      }
    }
    final tail = _parseSseFrame(buffer);
    if (tail != null && tail != _sseDone) yield tail as MisarMailStreamEvent;
  }
}

// ---------------------------------------------------------------------------
// Resources
// ---------------------------------------------------------------------------

class EmailResource extends _Resource {
  const EmailResource(super.client);
  Future<Map<String, dynamic>> send(Map<String, dynamic> data) =>
      _client._request('POST', '/send', body: data);
}

class ContactsResource extends _Resource {
  const ContactsResource(super.client);
  Future<Map<String, dynamic>> list({Map<String, dynamic>? params}) =>
      _client._request('GET', '/contacts', queryParams: params);
  Future<Map<String, dynamic>> create(Map<String, dynamic> data) =>
      _client._request('POST', '/contacts', body: data);
  Future<Map<String, dynamic>> get(String id) =>
      _client._request('GET', '/contacts/$id');
  Future<Map<String, dynamic>> update(String id, Map<String, dynamic> data) =>
      _client._request('PATCH', '/contacts/$id', body: data);
  Future<Map<String, dynamic>> delete(String id) =>
      _client._request('DELETE', '/contacts/$id');
  Future<Map<String, dynamic>> importContacts(Map<String, dynamic> data) =>
      _client._request('POST', '/contacts/import', body: data);
}

class CampaignsResource extends _Resource {
  const CampaignsResource(super.client);
  Future<Map<String, dynamic>> list({Map<String, dynamic>? params}) =>
      _client._request('GET', '/campaigns', queryParams: params);
  Future<Map<String, dynamic>> create(Map<String, dynamic> data) =>
      _client._request('POST', '/campaigns', body: data);
  Future<Map<String, dynamic>> get(String id) =>
      _client._request('GET', '/campaigns/$id');
  Future<Map<String, dynamic>> update(String id, Map<String, dynamic> data) =>
      _client._request('PATCH', '/campaigns/$id', body: data);
  Future<Map<String, dynamic>> send(String id) =>
      _client._request('POST', '/campaigns/$id/send');
  Future<Map<String, dynamic>> delete(String id) =>
      _client._request('DELETE', '/campaigns/$id');
}

class TemplatesResource extends _Resource {
  const TemplatesResource(super.client);
  Future<Map<String, dynamic>> list() =>
      _client._request('GET', '/templates');
  Future<Map<String, dynamic>> create(Map<String, dynamic> data) =>
      _client._request('POST', '/templates', body: data);
  Future<Map<String, dynamic>> get(String id) =>
      _client._request('GET', '/templates/$id');
  Future<Map<String, dynamic>> update(String id, Map<String, dynamic> data) =>
      _client._request('PATCH', '/templates/$id', body: data);
  Future<Map<String, dynamic>> delete(String id) =>
      _client._request('DELETE', '/templates/$id');
  Future<Map<String, dynamic>> render(Map<String, dynamic> data) =>
      _client._request('POST', '/templates/render', body: data);
}

class AutomationsResource extends _Resource {
  const AutomationsResource(super.client);
  Future<Map<String, dynamic>> list({Map<String, dynamic>? params}) =>
      _client._request('GET', '/automations', queryParams: params);
  Future<Map<String, dynamic>> create(Map<String, dynamic> data) =>
      _client._request('POST', '/automations', body: data);
  Future<Map<String, dynamic>> get(String id) =>
      _client._request('GET', '/automations/$id');
  Future<Map<String, dynamic>> update(String id, Map<String, dynamic> data) =>
      _client._request('PATCH', '/automations/$id', body: data);
  Future<Map<String, dynamic>> delete(String id) =>
      _client._request('DELETE', '/automations/$id');
  Future<Map<String, dynamic>> activate(String id, bool active) =>
      _client._request('POST', '/automations/$id/activate',
          body: {'active': active});
}

class DomainsResource extends _Resource {
  const DomainsResource(super.client);
  Future<Map<String, dynamic>> list() =>
      _client._request('GET', '/domains', useApiBase: true);
  Future<Map<String, dynamic>> create(Map<String, dynamic> data) =>
      _client._request('POST', '/domains', body: data, useApiBase: true);
  Future<Map<String, dynamic>> get(String id) =>
      _client._request('GET', '/domains/$id', useApiBase: true);
  Future<Map<String, dynamic>> verify(String id) =>
      _client._request('POST', '/domains/$id/verify', useApiBase: true);
  Future<Map<String, dynamic>> delete(String id) =>
      _client._request('DELETE', '/domains/$id', useApiBase: true);
}


class DedicatedIpsResource extends _Resource {
  const DedicatedIpsResource(super.client);
  Future<Map<String, dynamic>> list() =>
      _client._request('GET', '/dedicated-ips');
  Future<Map<String, dynamic>> create(Map<String, dynamic> data) =>
      _client._request('POST', '/dedicated-ips', body: data);
  Future<Map<String, dynamic>> update(String id, Map<String, dynamic> data) =>
      _client._request('PATCH', '/dedicated-ips/$id', body: data);
  Future<Map<String, dynamic>> delete(String id) =>
      _client._request('DELETE', '/dedicated-ips/$id');
}

class AbTestsResource extends _Resource {
  const AbTestsResource(super.client);
  Future<Map<String, dynamic>> list() =>
      _client._request('GET', '/ab-tests');
  Future<Map<String, dynamic>> create(Map<String, dynamic> data) =>
      _client._request('POST', '/ab-tests', body: data);
  Future<Map<String, dynamic>> get(String id) =>
      _client._request('GET', '/ab-tests/$id');
  Future<Map<String, dynamic>> setWinner(String id, String variantId) =>
      _client._request('POST', '/ab-tests/$id/winner',
          body: {'variantId': variantId});
}

class SandboxResource extends _Resource {
  const SandboxResource(super.client);
  Future<Map<String, dynamic>> send(Map<String, dynamic> data) =>
      _client._request('POST', '/sandbox/send', body: data);
  Future<Map<String, dynamic>> list({Map<String, dynamic>? params}) =>
      _client._request('GET', '/sandbox', queryParams: params);
  Future<Map<String, dynamic>> delete(String id) =>
      _client._request('DELETE', '/sandbox/$id');
}

class InboundResource extends _Resource {
  const InboundResource(super.client);
  Future<Map<String, dynamic>> list({Map<String, dynamic>? params}) =>
      _client._request('GET', '/inbound', queryParams: params);
  Future<Map<String, dynamic>> create(Map<String, dynamic> data) =>
      _client._request('POST', '/inbound', body: data);
  Future<Map<String, dynamic>> get(String id) =>
      _client._request('GET', '/inbound/$id');
  Future<Map<String, dynamic>> delete(String id) =>
      _client._request('DELETE', '/inbound/$id');
}

class AnalyticsResource extends _Resource {
  const AnalyticsResource(super.client);
  Future<Map<String, dynamic>> overview({Map<String, dynamic>? params}) =>
      _client._request('GET', '/analytics', queryParams: params);
}

class TrackResource extends _Resource {
  const TrackResource(super.client);
  Future<Map<String, dynamic>> event(Map<String, dynamic> data) =>
      _client._request('POST', '/track/event', body: data);
  Future<Map<String, dynamic>> purchase(Map<String, dynamic> data) =>
      _client._request('POST', '/track/purchase', body: data);
}

class KeysResource extends _Resource {
  const KeysResource(super.client);
  Future<Map<String, dynamic>> list() =>
      _client._request('GET', '/keys');
  Future<Map<String, dynamic>> create(Map<String, dynamic> data) =>
      _client._request('POST', '/keys', body: data);
  Future<Map<String, dynamic>> get(String id) =>
      _client._request('GET', '/keys/$id');
  Future<Map<String, dynamic>> revoke(String id) =>
      _client._request('DELETE', '/keys/$id');
}

class ValidateResource extends _Resource {
  const ValidateResource(super.client);
  Future<Map<String, dynamic>> email(String address) =>
      _client._request('POST', '/validate', body: {'email': address});
}

class WebhooksResource extends _Resource {
  const WebhooksResource(super.client);
  Future<Map<String, dynamic>> list() =>
      _client._request('GET', '/webhooks');
  Future<Map<String, dynamic>> create(Map<String, dynamic> data) =>
      _client._request('POST', '/webhooks', body: data);
  Future<Map<String, dynamic>> get(String id) =>
      _client._request('GET', '/webhooks/$id');
  Future<Map<String, dynamic>> update(String id, Map<String, dynamic> data) =>
      _client._request('PATCH', '/webhooks/$id', body: data);
  Future<Map<String, dynamic>> delete(String id) =>
      _client._request('DELETE', '/webhooks/$id');
  Future<Map<String, dynamic>> test(String id) =>
      _client._request('POST', '/webhooks/$id/test');
}

class UsageResource extends _Resource {
  const UsageResource(super.client);
  Future<Map<String, dynamic>> get({Map<String, dynamic>? params}) =>
      _client._request('GET', '/usage', queryParams: params);
}

class BillingResource extends _Resource {
  const BillingResource(super.client);
  Future<Map<String, dynamic>> subscription() =>
      _client._request('GET', '/billing/subscription', useApiBase: true);
  Future<Map<String, dynamic>> checkout(Map<String, dynamic> data) =>
      _client._request('POST', '/billing/checkout',
          body: data, useApiBase: true);
}


/// Live subscription standing for the key's owner.
///
/// Read this before an expensive call rather than discovering the ceiling
/// through a [MisarMailPlanLimitError]: `usage` reports every metered feature
/// and `upgrade` is non-null as soon as one of them is spent.
class PlanResource extends _Resource {
  const PlanResource(super.client);

  /// `GET /plan` — plan, sending allowances, per-feature usage, upgrade offer.
  Future<Map<String, dynamic>> get() => _client._request('GET', '/plan');

  /// `GET /monetization/stats` — revenue and monetization counters.
  Future<Map<String, dynamic>> monetization() =>
      _client._request('GET', '/monetization/stats');
}

// ── Generated from scripts/sdk-endpoint-spec.json ────────────────────────────
//
// These twenty endpoints were missing from every SDK except TypeScript.

/// `ai` — generated.
class AiResource extends _Resource {
  const AiResource(super.client);

  /// `POST /ai/subject-lines`
  Future<Map<String, dynamic>> subjectLines({Map<String, dynamic>? data}) =>
      _client._request('POST', '/ai/subject-lines', body: data ?? const {});

}

/// `creditRates` — generated.
class CreditRatesResource extends _Resource {
  const CreditRatesResource(super.client);

  /// `GET /credit-rates`
  Future<Map<String, dynamic>> list() =>
      _client._request('GET', '/credit-rates');

}

/// `deliverability` — generated.
class DeliverabilityResource extends _Resource {
  const DeliverabilityResource(super.client);

  /// `GET /deliverability/audit`
  Future<Map<String, dynamic>> audit() =>
      _client._request('GET', '/deliverability/audit');

  /// `GET /deliverability/score`
  Future<Map<String, dynamic>> score() =>
      _client._request('GET', '/deliverability/score');

}

/// `dmarc` — generated.
class DmarcResource extends _Resource {
  const DmarcResource(super.client);

  /// `GET /dmarc/check`
  Future<Map<String, dynamic>> check({String? domain, String? dkim_selector}) =>
      _client._request('GET', '/dmarc/check', queryParams: {'domain': domain, 'dkim_selector': dkim_selector});

  /// `GET /dmarc/domains`
  Future<Map<String, dynamic>> listDomains() =>
      _client._request('GET', '/dmarc/domains');

  /// `POST /dmarc/domains`
  Future<Map<String, dynamic>> addDomain({Map<String, dynamic>? data}) =>
      _client._request('POST', '/dmarc/domains', body: data ?? const {});

  /// `DELETE /dmarc/domains`
  Future<Map<String, dynamic>> removeDomain({String? domain_id}) =>
      _client._request('DELETE', '/dmarc/domains', queryParams: {'domain_id': domain_id});

}

/// `emailAccounts` — generated.
class EmailAccountsResource extends _Resource {
  const EmailAccountsResource(super.client);

  /// `GET /email-accounts`
  Future<Map<String, dynamic>> list() =>
      _client._request('GET', '/email-accounts');

}

/// `emails` — generated.
class EmailsResource extends _Resource {
  const EmailsResource(super.client);

  /// `GET /emails`
  Future<Map<String, dynamic>> list({String? folder, String? search, int? limit}) =>
      _client._request('GET', '/emails', queryParams: {'folder': folder, 'search': search, 'limit': limit});

  /// `GET /emails/:id`
  Future<Map<String, dynamic>> get(String id) =>
      _client._request('GET', '/emails/${Uri.encodeComponent(id)}');

  /// `PATCH /emails/:id`
  Future<Map<String, dynamic>> update(String id, {Map<String, dynamic>? data}) =>
      _client._request('PATCH', '/emails/${Uri.encodeComponent(id)}', body: data ?? const {});

}

/// `landingPages` — generated.
class LandingPagesResource extends _Resource {
  const LandingPagesResource(super.client);

  /// `POST /landing-pages`
  Future<Map<String, dynamic>> create({Map<String, dynamic>? data}) =>
      _client._request('POST', '/landing-pages', body: data ?? const {});

}

/// `monetization` — generated.
class MonetizationResource extends _Resource {
  const MonetizationResource(super.client);

  /// `POST /monetization/tip`
  Future<Map<String, dynamic>> tip({Map<String, dynamic>? data}) =>
      _client._request('POST', '/monetization/tip', body: data ?? const {});

}

/// `revenue` — generated.
class RevenueResource extends _Resource {
  const RevenueResource(super.client);

  /// `GET /revenue/attribution`
  Future<Map<String, dynamic>> attribution({String? campaign_id, String? period}) =>
      _client._request('GET', '/revenue/attribution', queryParams: {'campaign_id': campaign_id, 'period': period});

}

/// `segments` — generated.
class SegmentsResource extends _Resource {
  const SegmentsResource(super.client);

  /// `GET /segments/:id/members`
  Future<Map<String, dynamic>> members(String id, {int? page, int? limit}) =>
      _client._request('GET', '/segments/${Uri.encodeComponent(id)}/members', queryParams: {'page': page, 'limit': limit});

}

/// `subscription` — generated.
class SubscriptionResource extends _Resource {
  const SubscriptionResource(super.client);

  /// `GET /subscription`
  Future<Map<String, dynamic>> get({String? product}) =>
      _client._request('GET', '/subscription', queryParams: {'product': product});

  /// `POST /subscription`
  Future<Map<String, dynamic>> upsert({Map<String, dynamic>? data}) =>
      _client._request('POST', '/subscription', body: data ?? const {});

  /// `DELETE /subscription`
  Future<Map<String, dynamic>> cancel({Map<String, dynamic>? data}) =>
      _client._request('DELETE', '/subscription', body: data ?? const {});

}

/// `teamMembers` — generated.
class TeamMembersResource extends _Resource {
  const TeamMembersResource(super.client);

  /// `GET /team-members`
  Future<Map<String, dynamic>> get({String? owner_id}) =>
      _client._request('GET', '/team-members', queryParams: {'owner_id': owner_id});

}

/// `wallet` — generated.
class WalletResource extends _Resource {
  const WalletResource(super.client);

  /// `GET /wallet`
  Future<Map<String, dynamic>> get() =>
      _client._request('GET', '/wallet');

  /// `POST /wallet/credit`
  Future<Map<String, dynamic>> credit({Map<String, dynamic>? data}) =>
      _client._request('POST', '/wallet/credit', body: data ?? const {});

  /// `POST /wallet/debit`
  Future<Map<String, dynamic>> debit({Map<String, dynamic>? data}) =>
      _client._request('POST', '/wallet/debit', body: data ?? const {});

}

/// `warmup` — generated.
class WarmupResource extends _Resource {
  const WarmupResource(super.client);

  /// `GET /warmup`
  Future<Map<String, dynamic>> get() =>
      _client._request('GET', '/warmup');

}

// ── Server-Sent Events ───────────────────────────────────────────────────────

/// One decoded SSE frame.
///
/// MisarMail emits unnamed frames — `data: {...}` with no `event:` line — so
/// [event] is normally null. [data] is the decoded JSON, or the raw string when
/// the payload was not JSON.
class MisarMailStreamEvent {
  /// The SSE `event:` name, when the server sends one.
  final String? event;

  /// Decoded JSON payload, or the raw string.
  final dynamic data;

  const MisarMailStreamEvent(this.event, this.data);

  @override
  String toString() => 'MisarMailStreamEvent($event, $data)';
}

/// Sentinel returned by the frame parser for `data: [DONE]`.
const _sseDone = Object();

int _sseFrameEnd(String buffer) {
  final lf = buffer.indexOf('\n\n');
  final crlf = buffer.indexOf('\r\n\r\n');
  if (lf == -1) return crlf;
  if (crlf == -1) return lf;
  return lf < crlf ? lf : crlf;
}

/// Decodes one frame. Returns [_sseDone] for the terminating sentinel, or null
/// for a keepalive comment or empty frame.
Object? _parseSseFrame(String frame) {
  String? event;
  final dataLines = <String>[];

  for (final line in frame.replaceAll('\r\n', '\n').split('\n')) {
    if (line.isEmpty || line.startsWith(':')) continue;
    if (line.startsWith('event:')) {
      event = line.substring(6).trim();
    } else if (line.startsWith('data:')) {
      dataLines.add(line.substring(5).replaceFirst(RegExp(r'^ '), ''));
    }
  }
  if (dataLines.isEmpty) return null;

  final raw = dataLines.join('\n');
  if (raw == '[DONE]') return _sseDone;

  dynamic decoded;
  try {
    decoded = jsonDecode(raw);
  } catch (_) {
    decoded = raw;
  }
  return MisarMailStreamEvent(event, decoded);
}

/// The two Server-Sent Events endpoints.
///
/// Both live outside `/v1` and are API-key authenticated like everything else,
/// so a plan refusal surfaces as [MisarMailPlanLimitError] here too.
class StreamingResource extends _Resource {
  const StreamingResource(super.client);

  /// `POST /api/ai/generate-email/stream` — token-by-token generation.
  ///
  /// ```dart
  /// await for (final e in mail.streaming.generateEmail({'prompt': '…'})) {
  ///   stdout.write(e.data['delta'] ?? '');
  /// }
  /// ```
  Stream<MisarMailStreamEvent> generateEmail(Map<String, dynamic> options) =>
      _client._sseStream('POST', '/ai/generate-email/stream', body: options);

  /// `GET /api/campaigns/{id}/send-stream` — live send progress.
  Stream<MisarMailStreamEvent> campaignSend(String campaignId) => _client._sseStream(
        'GET',
        '/campaigns/${Uri.encodeComponent(campaignId)}/send-stream',
      );
}
