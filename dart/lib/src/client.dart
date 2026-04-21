import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'errors.dart';

abstract class _Resource {
  final MisarMailClient _client;
  const _Resource(this._client);
}

String _deriveApiBase(String? baseUrl) {
  final b = (baseUrl ?? 'https://mail.misar.io/api/v1')
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

  late final EmailResource email;
  late final ContactsResource contacts;
  late final CampaignsResource campaigns;
  late final TemplatesResource templates;
  late final AutomationsResource automations;
  late final DomainsResource domains;
  late final AliasesResource aliases;
  late final DedicatedIpsResource dedicatedIps;
  late final ChannelsResource channels;
  late final AbTestsResource abTests;
  late final SandboxResource sandbox;
  late final InboundResource inbound;
  late final AnalyticsResource analytics;
  late final TrackResource track;
  late final KeysResource keys;
  late final ValidateResource validate;
  late final LeadsResource leads;
  late final AutopilotResource autopilot;
  late final SalesAgentResource salesAgent;
  late final CrmResource crm;
  late final WebhooksResource webhooks;
  late final UsageResource usage;
  late final BillingResource billing;
  late final WorkspacesResource workspaces;

  MisarMailClient({
    required String apiKey,
    String? baseUrl,
    int maxRetries = 3,
    http.Client? httpClient,
  })  : _apiKey = apiKey,
        _baseUrl = (baseUrl ?? 'https://mail.misar.io/api/v1')
            .replaceAll(RegExp(r'/$'), ''),
        _apiBase = _deriveApiBase(baseUrl),
        _maxRetries = maxRetries,
        _httpClient = httpClient ?? http.Client() {
    email = EmailResource(this);
    contacts = ContactsResource(this);
    campaigns = CampaignsResource(this);
    templates = TemplatesResource(this);
    automations = AutomationsResource(this);
    domains = DomainsResource(this);
    aliases = AliasesResource(this);
    dedicatedIps = DedicatedIpsResource(this);
    channels = ChannelsResource(this);
    abTests = AbTestsResource(this);
    sandbox = SandboxResource(this);
    inbound = InboundResource(this);
    analytics = AnalyticsResource(this);
    track = TrackResource(this);
    keys = KeysResource(this);
    validate = ValidateResource(this);
    leads = LeadsResource(this);
    autopilot = AutopilotResource(this);
    salesAgent = SalesAgentResource(this);
    crm = CrmResource(this);
    webhooks = WebhooksResource(this);
    usage = UsageResource(this);
    billing = BillingResource(this);
    workspaces = WorkspacesResource(this);
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
      _client._request('GET', '/domains');
  Future<Map<String, dynamic>> create(Map<String, dynamic> data) =>
      _client._request('POST', '/domains', body: data);
  Future<Map<String, dynamic>> get(String id) =>
      _client._request('GET', '/domains/$id');
  Future<Map<String, dynamic>> verify(String id) =>
      _client._request('POST', '/domains/$id/verify');
  Future<Map<String, dynamic>> delete(String id) =>
      _client._request('DELETE', '/domains/$id');
}

class AliasesResource extends _Resource {
  const AliasesResource(super.client);
  Future<Map<String, dynamic>> list() =>
      _client._request('GET', '/aliases');
  Future<Map<String, dynamic>> create(Map<String, dynamic> data) =>
      _client._request('POST', '/aliases', body: data);
  Future<Map<String, dynamic>> get(String id) =>
      _client._request('GET', '/aliases/$id');
  Future<Map<String, dynamic>> update(String id, Map<String, dynamic> data) =>
      _client._request('PATCH', '/aliases/$id', body: data);
  Future<Map<String, dynamic>> delete(String id) =>
      _client._request('DELETE', '/aliases/$id');
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

class ChannelsResource extends _Resource {
  const ChannelsResource(super.client);
  Future<Map<String, dynamic>> sendWhatsapp(Map<String, dynamic> data) =>
      _client._request('POST', '/channels/whatsapp', body: data);
  Future<Map<String, dynamic>> sendPush(Map<String, dynamic> data) =>
      _client._request('POST', '/channels/push', body: data);
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
      _client._request('POST', '/validate/email', body: {'email': address});
}

class LeadsResource extends _Resource {
  const LeadsResource(super.client);
  Future<Map<String, dynamic>> search(Map<String, dynamic> data) =>
      _client._request('POST', '/leads/search', body: data);
  Future<Map<String, dynamic>> getJob(String id) =>
      _client._request('GET', '/leads/jobs/$id');
  Future<Map<String, dynamic>> listJobs({Map<String, dynamic>? params}) =>
      _client._request('GET', '/leads/jobs', queryParams: params);
  Future<Map<String, dynamic>> results(String jobId) =>
      _client._request('GET', '/leads/jobs/$jobId/results');
  Future<Map<String, dynamic>> importLeads(Map<String, dynamic> data) =>
      _client._request('POST', '/leads/import', body: data);
  Future<Map<String, dynamic>> credits() =>
      _client._request('GET', '/leads/credits');
}

class AutopilotResource extends _Resource {
  const AutopilotResource(super.client);
  Future<Map<String, dynamic>> start(Map<String, dynamic> data) =>
      _client._request('POST', '/autopilot', body: data);
  Future<Map<String, dynamic>> get(String id) =>
      _client._request('GET', '/autopilot/$id');
  Future<Map<String, dynamic>> list({Map<String, dynamic>? params}) =>
      _client._request('GET', '/autopilot', queryParams: params);
  Future<Map<String, dynamic>> dailyPlan() =>
      _client._request('GET', '/autopilot/daily-plan');
}

class SalesAgentResource extends _Resource {
  const SalesAgentResource(super.client);
  Future<Map<String, dynamic>> getConfig() =>
      _client._request('GET', '/sales-agent/config');
  Future<Map<String, dynamic>> updateConfig(Map<String, dynamic> data) =>
      _client._request('PATCH', '/sales-agent/config', body: data);
  Future<Map<String, dynamic>> getActions({Map<String, dynamic>? params}) =>
      _client._request('GET', '/sales-agent/actions', queryParams: params);
}

class CrmResource extends _Resource {
  const CrmResource(super.client);
  Future<Map<String, dynamic>> listConversations(
          {Map<String, dynamic>? params}) =>
      _client._request('GET', '/crm/conversations', queryParams: params);
  Future<Map<String, dynamic>> getConversation(String id) =>
      _client._request('GET', '/crm/conversations/$id');
  Future<Map<String, dynamic>> updateConversation(
          String id, Map<String, dynamic> data) =>
      _client._request('PATCH', '/crm/conversations/$id', body: data);
  Future<Map<String, dynamic>> listMessages(String conversationId) =>
      _client._request('GET',
          '/crm/conversations/$conversationId/messages');
  Future<Map<String, dynamic>> listDeals({Map<String, dynamic>? params}) =>
      _client._request('GET', '/crm/deals', queryParams: params);
  Future<Map<String, dynamic>> createDeal(Map<String, dynamic> data) =>
      _client._request('POST', '/crm/deals', body: data);
  Future<Map<String, dynamic>> getDeal(String id) =>
      _client._request('GET', '/crm/deals/$id');
  Future<Map<String, dynamic>> updateDeal(String id, Map<String, dynamic> data) =>
      _client._request('PATCH', '/crm/deals/$id', body: data);
  Future<Map<String, dynamic>> deleteDeal(String id) =>
      _client._request('DELETE', '/crm/deals/$id');
  Future<Map<String, dynamic>> listClients({Map<String, dynamic>? params}) =>
      _client._request('GET', '/crm/clients', queryParams: params);
  Future<Map<String, dynamic>> createClient(Map<String, dynamic> data) =>
      _client._request('POST', '/crm/clients', body: data);
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

class WorkspacesResource extends _Resource {
  const WorkspacesResource(super.client);
  Future<Map<String, dynamic>> list() =>
      _client._request('GET', '/workspaces', useApiBase: true);
  Future<Map<String, dynamic>> create(Map<String, dynamic> data) =>
      _client._request('POST', '/workspaces', body: data, useApiBase: true);
  Future<Map<String, dynamic>> get(String id) =>
      _client._request('GET', '/workspaces/$id', useApiBase: true);
  Future<Map<String, dynamic>> update(String id, Map<String, dynamic> data) =>
      _client._request('PATCH', '/workspaces/$id',
          body: data, useApiBase: true);
  Future<Map<String, dynamic>> delete(String id) =>
      _client._request('DELETE', '/workspaces/$id', useApiBase: true);
  Future<Map<String, dynamic>> listMembers(String wsId) =>
      _client._request('GET', '/workspaces/$wsId/members', useApiBase: true);
  Future<Map<String, dynamic>> inviteMember(
          String wsId, Map<String, dynamic> data) =>
      _client._request('POST', '/workspaces/$wsId/members',
          body: data, useApiBase: true);
  Future<Map<String, dynamic>> updateMember(
          String wsId, String userId, Map<String, dynamic> data) =>
      _client._request('PATCH', '/workspaces/$wsId/members/$userId',
          body: data, useApiBase: true);
  Future<Map<String, dynamic>> removeMember(String wsId, String userId) =>
      _client._request('DELETE', '/workspaces/$wsId/members/$userId',
          useApiBase: true);
}
