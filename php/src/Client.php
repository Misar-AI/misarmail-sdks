<?php

declare(strict_types=1);

namespace MisarMail;

// ── Resource: Email ───────────────────────────────────────────────────────────

class EmailResource
{
    public function __construct(private readonly Client $client) {}

    public function send(array $data): array
    {
        return $this->client->request('POST', '/send', $data);
    }
}

// ── Resource: Contacts ────────────────────────────────────────────────────────

class ContactsResource
{
    public function __construct(private readonly Client $client) {}

    public function list(int $page = 1, int $limit = 20): array
    {
        return $this->client->request('GET', '/contacts?' . http_build_query(['page' => $page, 'limit' => $limit]));
    }

    public function create(array $data): array
    {
        return $this->client->request('POST', '/contacts', $data);
    }

    public function get(string $id): array
    {
        return $this->client->request('GET', "/contacts/{$id}");
    }

    public function update(string $id, array $data): array
    {
        return $this->client->request('PATCH', "/contacts/{$id}", $data);
    }

    public function delete(string $id): array
    {
        return $this->client->request('DELETE', "/contacts/{$id}");
    }

    public function import(array $data): array
    {
        return $this->client->request('POST', '/contacts/import', $data);
    }
}

// ── Resource: Campaigns ───────────────────────────────────────────────────────

class CampaignsResource
{
    public function __construct(private readonly Client $client) {}

    public function list(array $params = []): array
    {
        $qs = $params ? '?' . http_build_query($params) : '';
        return $this->client->request('GET', "/campaigns{$qs}");
    }

    public function create(array $data): array
    {
        return $this->client->request('POST', '/campaigns', $data);
    }

    public function get(string $id): array
    {
        return $this->client->request('GET', "/campaigns/{$id}");
    }

    public function update(string $id, array $data): array
    {
        return $this->client->request('PATCH', "/campaigns/{$id}", $data);
    }

    public function send(string $id): array
    {
        return $this->client->request('POST', "/campaigns/{$id}/send");
    }

    public function delete(string $id): array
    {
        return $this->client->request('DELETE', "/campaigns/{$id}");
    }
}

// ── Resource: Templates ───────────────────────────────────────────────────────

class TemplatesResource
{
    public function __construct(private readonly Client $client) {}

    public function list(): array
    {
        return $this->client->request('GET', '/templates');
    }

    public function create(array $data): array
    {
        return $this->client->request('POST', '/templates', $data);
    }

    public function get(string $id): array
    {
        return $this->client->request('GET', "/templates/{$id}");
    }

    public function update(string $id, array $data): array
    {
        return $this->client->request('PATCH', "/templates/{$id}", $data);
    }

    public function delete(string $id): array
    {
        return $this->client->request('DELETE', "/templates/{$id}");
    }

    public function render(array $data): array
    {
        return $this->client->request('POST', '/templates/render', $data);
    }
}

// ── Resource: Automations ─────────────────────────────────────────────────────

class AutomationsResource
{
    public function __construct(private readonly Client $client) {}

    public function list(array $params = []): array
    {
        $qs = $params ? '?' . http_build_query($params) : '';
        return $this->client->request('GET', "/automations{$qs}");
    }

    public function create(array $data): array
    {
        return $this->client->request('POST', '/automations', $data);
    }

    public function get(string $id): array
    {
        return $this->client->request('GET', "/automations/{$id}");
    }

    public function update(string $id, array $data): array
    {
        return $this->client->request('PATCH', "/automations/{$id}", $data);
    }

    public function delete(string $id): array
    {
        return $this->client->request('DELETE', "/automations/{$id}");
    }

    public function activate(string $id, bool $active): array
    {
        return $this->client->request('POST', "/automations/{$id}/activate", ['active' => $active]);
    }
}

// ── Resource: Domains ─────────────────────────────────────────────────────────

class DomainsResource
{
    public function __construct(private readonly Client $client) {}

    public function list(): array
    {
        return $this->client->request('GET', '/domains');
    }

    public function create(array $data): array
    {
        return $this->client->request('POST', '/domains', $data);
    }

    public function get(string $id): array
    {
        return $this->client->request('GET', "/domains/{$id}");
    }

    public function verify(string $id): array
    {
        return $this->client->request('POST', "/domains/{$id}/verify");
    }

    public function delete(string $id): array
    {
        return $this->client->request('DELETE', "/domains/{$id}");
    }
}

// ── Resource: Aliases ─────────────────────────────────────────────────────────

class AliasesResource
{
    public function __construct(private readonly Client $client) {}

    public function list(): array
    {
        return $this->client->request('GET', '/aliases');
    }

    public function create(array $data): array
    {
        return $this->client->request('POST', '/aliases', $data);
    }

    public function get(string $id): array
    {
        return $this->client->request('GET', "/aliases/{$id}");
    }

    public function update(string $id, array $data): array
    {
        return $this->client->request('PATCH', "/aliases/{$id}", $data);
    }

    public function delete(string $id): array
    {
        return $this->client->request('DELETE', "/aliases/{$id}");
    }
}

// ── Resource: Dedicated IPs ───────────────────────────────────────────────────

class DedicatedIpsResource
{
    public function __construct(private readonly Client $client) {}

    public function list(): array
    {
        return $this->client->request('GET', '/dedicated-ips');
    }

    public function create(array $data): array
    {
        return $this->client->request('POST', '/dedicated-ips', $data);
    }

    public function update(string $id, array $data): array
    {
        return $this->client->request('PATCH', "/dedicated-ips/{$id}", $data);
    }

    public function delete(string $id): array
    {
        return $this->client->request('DELETE', "/dedicated-ips/{$id}");
    }
}

// ── Resource: Channels ────────────────────────────────────────────────────────

class ChannelsResource
{
    public function __construct(private readonly Client $client) {}

    public function sendWhatsapp(array $data): array
    {
        return $this->client->request('POST', '/channels/whatsapp/send', $data);
    }

    public function sendPush(array $data): array
    {
        return $this->client->request('POST', '/channels/push/send', $data);
    }
}

// ── Resource: A/B Tests ───────────────────────────────────────────────────────

class AbTestsResource
{
    public function __construct(private readonly Client $client) {}

    public function list(): array
    {
        return $this->client->request('GET', '/ab-tests');
    }

    public function create(array $data): array
    {
        return $this->client->request('POST', '/ab-tests', $data);
    }

    public function get(string $id): array
    {
        return $this->client->request('GET', "/ab-tests/{$id}");
    }

    public function setWinner(string $id, string $variantId): array
    {
        return $this->client->request('POST', "/ab-tests/{$id}/winner", ['variant_id' => $variantId]);
    }
}

// ── Resource: Sandbox ─────────────────────────────────────────────────────────

class SandboxResource
{
    public function __construct(private readonly Client $client) {}

    public function send(array $data): array
    {
        return $this->client->request('POST', '/sandbox/send', $data);
    }

    public function list(array $params = []): array
    {
        $qs = $params ? '?' . http_build_query($params) : '';
        return $this->client->request('GET', "/sandbox{$qs}");
    }

    public function delete(string $id): array
    {
        return $this->client->request('DELETE', "/sandbox/{$id}");
    }
}

// ── Resource: Inbound ─────────────────────────────────────────────────────────

class InboundResource
{
    public function __construct(private readonly Client $client) {}

    public function list(array $params = []): array
    {
        $qs = $params ? '?' . http_build_query($params) : '';
        return $this->client->request('GET', "/inbound{$qs}");
    }

    public function create(array $data): array
    {
        return $this->client->request('POST', '/inbound', $data);
    }

    public function get(string $id): array
    {
        return $this->client->request('GET', "/inbound/{$id}");
    }

    public function delete(string $id): array
    {
        return $this->client->request('DELETE', "/inbound/{$id}");
    }
}

// ── Resource: Analytics ───────────────────────────────────────────────────────

class AnalyticsResource
{
    public function __construct(private readonly Client $client) {}

    public function overview(array $params = []): array
    {
        $qs = $params ? '?' . http_build_query($params) : '';
        return $this->client->request('GET', "/analytics{$qs}");
    }
}

// ── Resource: Track ───────────────────────────────────────────────────────────

class TrackResource
{
    public function __construct(private readonly Client $client) {}

    public function event(array $data): array
    {
        return $this->client->request('POST', '/track/event', $data);
    }

    public function purchase(array $data): array
    {
        return $this->client->request('POST', '/track/purchase', $data);
    }
}

// ── Resource: API Keys ────────────────────────────────────────────────────────

class KeysResource
{
    public function __construct(private readonly Client $client) {}

    public function list(): array
    {
        return $this->client->request('GET', '/keys');
    }

    public function create(array $data): array
    {
        return $this->client->request('POST', '/keys', $data);
    }

    public function get(string $id): array
    {
        return $this->client->request('GET', "/keys/{$id}");
    }

    public function revoke(string $id): array
    {
        return $this->client->request('DELETE', "/keys/{$id}");
    }
}

// ── Resource: Validate ────────────────────────────────────────────────────────

class ValidateResource
{
    public function __construct(private readonly Client $client) {}

    public function email(string $address): array
    {
        return $this->client->request('POST', '/validate/email', ['email' => $address]);
    }
}

// ── Resource: Leads ───────────────────────────────────────────────────────────

class LeadsResource
{
    public function __construct(private readonly Client $client) {}

    public function search(array $data): array
    {
        return $this->client->request('POST', '/leads/search', $data);
    }

    public function getJob(string $id): array
    {
        return $this->client->request('GET', "/leads/jobs/{$id}");
    }

    public function listJobs(array $params = []): array
    {
        $qs = $params ? '?' . http_build_query($params) : '';
        return $this->client->request('GET', "/leads/jobs{$qs}");
    }

    public function results(string $jobId): array
    {
        return $this->client->request('GET', "/leads/jobs/{$jobId}/results");
    }

    public function import(array $data): array
    {
        return $this->client->request('POST', '/leads/import', $data);
    }

    public function credits(): array
    {
        return $this->client->request('GET', '/leads/credits');
    }
}

// ── Resource: Autopilot ───────────────────────────────────────────────────────

class AutopilotResource
{
    public function __construct(private readonly Client $client) {}

    public function start(array $data): array
    {
        return $this->client->request('POST', '/autopilot', $data);
    }

    public function get(string $id): array
    {
        return $this->client->request('GET', "/autopilot/{$id}");
    }

    public function list(array $params = []): array
    {
        $qs = $params ? '?' . http_build_query($params) : '';
        return $this->client->request('GET', "/autopilot{$qs}");
    }

    public function dailyPlan(): array
    {
        return $this->client->request('GET', '/autopilot/daily-plan');
    }
}

// ── Resource: Sales Agent ─────────────────────────────────────────────────────

class SalesAgentResource
{
    public function __construct(private readonly Client $client) {}

    public function getConfig(): array
    {
        return $this->client->request('GET', '/sales-agent/config');
    }

    public function updateConfig(array $data): array
    {
        return $this->client->request('PATCH', '/sales-agent/config', $data);
    }

    public function getActions(array $params = []): array
    {
        $qs = $params ? '?' . http_build_query($params) : '';
        return $this->client->request('GET', "/sales-agent/actions{$qs}");
    }
}

// ── Resource: CRM ─────────────────────────────────────────────────────────────

class CrmResource
{
    public function __construct(private readonly Client $client) {}

    public function listConversations(array $params = []): array
    {
        $qs = $params ? '?' . http_build_query($params) : '';
        return $this->client->request('GET', "/crm/conversations{$qs}");
    }

    public function getConversation(string $id): array
    {
        return $this->client->request('GET', "/crm/conversations/{$id}");
    }

    public function updateConversation(string $id, array $data): array
    {
        return $this->client->request('PATCH', "/crm/conversations/{$id}", $data);
    }

    public function listMessages(string $conversationId): array
    {
        return $this->client->request('GET', "/crm/conversations/{$conversationId}/messages");
    }

    public function listDeals(array $params = []): array
    {
        $qs = $params ? '?' . http_build_query($params) : '';
        return $this->client->request('GET', "/crm/deals{$qs}");
    }

    public function createDeal(array $data): array
    {
        return $this->client->request('POST', '/crm/deals', $data);
    }

    public function getDeal(string $id): array
    {
        return $this->client->request('GET', "/crm/deals/{$id}");
    }

    public function updateDeal(string $id, array $data): array
    {
        return $this->client->request('PATCH', "/crm/deals/{$id}", $data);
    }

    public function deleteDeal(string $id): array
    {
        return $this->client->request('DELETE', "/crm/deals/{$id}");
    }

    public function listClients(array $params = []): array
    {
        $qs = $params ? '?' . http_build_query($params) : '';
        return $this->client->request('GET', "/crm/clients{$qs}");
    }

    public function createClient(array $data): array
    {
        return $this->client->request('POST', '/crm/clients', $data);
    }
}

// ── Resource: Webhooks ────────────────────────────────────────────────────────

class WebhooksResource
{
    public function __construct(private readonly Client $client) {}

    public function list(): array
    {
        return $this->client->request('GET', '/webhooks');
    }

    public function create(array $data): array
    {
        return $this->client->request('POST', '/webhooks', $data);
    }

    public function get(string $id): array
    {
        return $this->client->request('GET', "/webhooks/{$id}");
    }

    public function update(string $id, array $data): array
    {
        return $this->client->request('PATCH', "/webhooks/{$id}", $data);
    }

    public function delete(string $id): array
    {
        return $this->client->request('DELETE', "/webhooks/{$id}");
    }

    public function test(string $id): array
    {
        return $this->client->request('POST', "/webhooks/{$id}/test");
    }
}

// ── Resource: Usage ───────────────────────────────────────────────────────────

class UsageResource
{
    public function __construct(private readonly Client $client) {}

    public function get(array $params = []): array
    {
        $qs = $params ? '?' . http_build_query($params) : '';
        return $this->client->request('GET', "/usage{$qs}");
    }
}

// ── Resource: Billing ─────────────────────────────────────────────────────────

class BillingResource
{
    private const BILLING_BASE = 'https://mail.misar.io/api';

    public function __construct(private readonly Client $client) {}

    public function subscription(): array
    {
        return $this->client->request('GET', '/billing/subscription', [], self::BILLING_BASE);
    }

    public function checkout(array $data): array
    {
        return $this->client->request('POST', '/billing/checkout', $data, self::BILLING_BASE);
    }
}

// ── Resource: Workspaces ──────────────────────────────────────────────────────

class WorkspacesResource
{
    private const BILLING_BASE = 'https://mail.misar.io/api';

    public function __construct(private readonly Client $client) {}

    public function list(): array
    {
        return $this->client->request('GET', '/workspaces', [], self::BILLING_BASE);
    }

    public function create(array $data): array
    {
        return $this->client->request('POST', '/workspaces', $data, self::BILLING_BASE);
    }

    public function get(string $id): array
    {
        return $this->client->request('GET', "/workspaces/{$id}", [], self::BILLING_BASE);
    }

    public function update(string $id, array $data): array
    {
        return $this->client->request('PATCH', "/workspaces/{$id}", $data, self::BILLING_BASE);
    }

    public function delete(string $id): array
    {
        return $this->client->request('DELETE', "/workspaces/{$id}", [], self::BILLING_BASE);
    }

    public function listMembers(string $wsId): array
    {
        return $this->client->request('GET', "/workspaces/{$wsId}/members", [], self::BILLING_BASE);
    }

    public function inviteMember(string $wsId, array $data): array
    {
        return $this->client->request('POST', "/workspaces/{$wsId}/members", $data, self::BILLING_BASE);
    }

    public function updateMember(string $wsId, string $userId, array $data): array
    {
        return $this->client->request('PATCH', "/workspaces/{$wsId}/members/{$userId}", $data, self::BILLING_BASE);
    }

    public function removeMember(string $wsId, string $userId): array
    {
        return $this->client->request('DELETE', "/workspaces/{$wsId}/members/{$userId}", [], self::BILLING_BASE);
    }
}

// ── Main Client ───────────────────────────────────────────────────────────────

class Client
{
    public readonly EmailResource        $email;
    public readonly ContactsResource     $contacts;
    public readonly CampaignsResource    $campaigns;
    public readonly TemplatesResource    $templates;
    public readonly AutomationsResource  $automations;
    public readonly DomainsResource      $domains;
    public readonly AliasesResource      $aliases;
    public readonly DedicatedIpsResource $dedicatedIps;
    public readonly ChannelsResource     $channels;
    public readonly AbTestsResource      $abTests;
    public readonly SandboxResource      $sandbox;
    public readonly InboundResource      $inbound;
    public readonly AnalyticsResource    $analytics;
    public readonly TrackResource        $track;
    public readonly KeysResource         $keys;
    public readonly ValidateResource     $validate;
    public readonly LeadsResource        $leads;
    public readonly AutopilotResource    $autopilot;
    public readonly SalesAgentResource   $salesAgent;
    public readonly CrmResource          $crm;
    public readonly WebhooksResource     $webhooks;
    public readonly UsageResource        $usage;
    public readonly BillingResource      $billing;
    public readonly WorkspacesResource   $workspaces;

    private const BASE_URL      = 'https://mail.misar.io/api/v1';
    private const RETRYABLE     = [429, 500, 502, 503, 504];
    private const RETRY_BASE_MS = 300;
    private const MAX_RETRIES   = 3;

    public function __construct(
        private readonly string $apiKey,
        private readonly int    $timeout = 30,
    ) {
        $this->email        = new EmailResource($this);
        $this->contacts     = new ContactsResource($this);
        $this->campaigns    = new CampaignsResource($this);
        $this->templates    = new TemplatesResource($this);
        $this->automations  = new AutomationsResource($this);
        $this->domains      = new DomainsResource($this);
        $this->aliases      = new AliasesResource($this);
        $this->dedicatedIps = new DedicatedIpsResource($this);
        $this->channels     = new ChannelsResource($this);
        $this->abTests      = new AbTestsResource($this);
        $this->sandbox      = new SandboxResource($this);
        $this->inbound      = new InboundResource($this);
        $this->analytics    = new AnalyticsResource($this);
        $this->track        = new TrackResource($this);
        $this->keys         = new KeysResource($this);
        $this->validate     = new ValidateResource($this);
        $this->leads        = new LeadsResource($this);
        $this->autopilot    = new AutopilotResource($this);
        $this->salesAgent   = new SalesAgentResource($this);
        $this->crm          = new CrmResource($this);
        $this->webhooks     = new WebhooksResource($this);
        $this->usage        = new UsageResource($this);
        $this->billing      = new BillingResource($this);
        $this->workspaces   = new WorkspacesResource($this);
    }

    /**
     * @throws ApiError
     * @throws NetworkError
     */
    public function request(
        string  $method,
        string  $path,
        array   $data = [],
        ?string $baseOverride = null,
    ): array {
        $base     = rtrim($baseOverride ?? self::BASE_URL, '/');
        $url      = $base . '/' . ltrim($path, '/');
        $hasBody  = !empty($data) && in_array($method, ['POST', 'PUT', 'PATCH'], true);
        $jsonBody = $hasBody ? json_encode($data, JSON_THROW_ON_ERROR) : null;

        $headers = [
            'Authorization: Bearer ' . $this->apiKey,
            'Content-Type: application/json',
            'Accept: application/json',
        ];

        $lastStatus = 0;

        for ($attempt = 0; $attempt < self::MAX_RETRIES; $attempt++) {
            $ch = curl_init();

            curl_setopt_array($ch, [
                CURLOPT_URL            => $url,
                CURLOPT_RETURNTRANSFER => true,
                CURLOPT_HTTPHEADER     => $headers,
                CURLOPT_CUSTOMREQUEST  => $method,
                CURLOPT_TIMEOUT        => $this->timeout,
                CURLOPT_CONNECTTIMEOUT => 10,
                CURLOPT_FOLLOWLOCATION => false,
            ]);

            if ($jsonBody !== null) {
                curl_setopt($ch, CURLOPT_POSTFIELDS, $jsonBody);
            }

            $body      = curl_exec($ch);
            $curlErrno = curl_errno($ch);
            $curlError = curl_error($ch);
            $status    = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);
            curl_close($ch);

            if ($curlErrno !== 0) {
                if ($attempt < self::MAX_RETRIES - 1) {
                    usleep(self::RETRY_BASE_MS * (1 << $attempt) * 1000);
                    continue;
                }
                throw new NetworkError("cURL error ({$curlErrno}): {$curlError}");
            }

            $lastStatus = $status;

            if (in_array($status, self::RETRYABLE, true) && $attempt < self::MAX_RETRIES - 1) {
                usleep(self::RETRY_BASE_MS * (1 << $attempt) * 1000);
                continue;
            }

            if ($status === 204 || $body === '' || $body === false) {
                return [];
            }

            $decoded = json_decode((string) $body, true);

            if ($status >= 400) {
                $msg = is_array($decoded)
                    ? ($decoded['error'] ?? $decoded['message'] ?? (string) $body)
                    : (string) $body;
                throw new ApiError($msg, $status);
            }

            return is_array($decoded) ? $decoded : [];
        }

        throw new ApiError('Max retries exceeded', $lastStatus);
    }
}
