using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;

namespace Misar.Mail;

/// <summary>
/// MisarMail API client (C# 10+, System.Text.Json).
///
/// All methods perform up to <see cref="MaxRetries"/> attempts with
/// exponential back-off (starting at 500 ms) on retryable HTTP statuses
/// (429, 500, 502, 503, 504).
/// </summary>
public sealed class MisarMailClient : IDisposable
{
    private static readonly HashSet<int> RetryableStatuses = [429, 500, 502, 503, 504];

    private readonly string _apiKey;
    private readonly string _baseUrl;
    private readonly string _apiBase;   // billing/workspaces — no /v1
    private readonly int _maxRetries;
    private readonly HttpClient _httpClient;
    private readonly bool _ownsHttpClient;

    public int MaxRetries => _maxRetries;

    public MisarMailClient(
        string apiKey,
        string baseUrl = "https://mail.misar.io/api/v1",
        int maxRetries = 3,
        HttpClient? httpClient = null)
    {
        if (string.IsNullOrWhiteSpace(apiKey))
            throw new ArgumentException("apiKey must not be blank.", nameof(apiKey));

        _apiKey = apiKey;
        _baseUrl = baseUrl.TrimEnd('/');
        _apiBase = _baseUrl.EndsWith("/v1", StringComparison.OrdinalIgnoreCase)
            ? _baseUrl[..^3]
            : _baseUrl;
        _maxRetries = maxRetries;
        _ownsHttpClient = httpClient is null;
        _httpClient = httpClient ?? new HttpClient { Timeout = TimeSpan.FromSeconds(30) };
    }

    // -------------------------------------------------------------------------
    // Core request logic
    // -------------------------------------------------------------------------

    private async Task<JsonElement> RequestAsync(
        HttpMethod method,
        string path,
        object? body = null,
        bool useApiBase = false,
        CancellationToken cancellationToken = default)
    {
        string url = (useApiBase ? _apiBase : _baseUrl) + path;
        string? bodyJson = body is not null
            ? JsonSerializer.Serialize(body)
            : method == HttpMethod.Post ? "{}" : null;

        Exception? lastException = null;

        for (int attempt = 0; attempt < _maxRetries; attempt++)
        {
            if (attempt > 0)
            {
                int delayMs = 500 * (1 << (attempt - 1));
                await Task.Delay(delayMs, cancellationToken).ConfigureAwait(false);
            }

            using var request = new HttpRequestMessage(method, url);
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _apiKey);
            request.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));

            if (bodyJson is not null)
                request.Content = new StringContent(bodyJson, Encoding.UTF8, "application/json");

            HttpResponseMessage response;
            try
            {
                response = await _httpClient.SendAsync(request, cancellationToken).ConfigureAwait(false);
            }
            catch (Exception ex) when (ex is HttpRequestException or TaskCanceledException)
            {
                lastException = ex;
                continue;
            }

            using (response)
            {
                int status = (int)response.StatusCode;

                if (RetryableStatuses.Contains(status) && attempt < _maxRetries - 1)
                {
                    lastException = new MisarMailException(status, "retryable error");
                    continue;
                }

                string responseBody = await response.Content
                    .ReadAsStringAsync(cancellationToken).ConfigureAwait(false);

                if (response.IsSuccessStatusCode)
                {
                    if (string.IsNullOrWhiteSpace(responseBody))
                        return JsonDocument.Parse("{}").RootElement.Clone();
                    using var doc = JsonDocument.Parse(responseBody);
                    return doc.RootElement.Clone();
                }

                throw new MisarMailException(status, ExtractError(responseBody));
            }
        }

        throw new MisarMailNetworkException($"max retries exceeded: {lastException?.Message ?? "unknown"}");
    }

    private static string ExtractError(string body)
    {
        try
        {
            using var doc = JsonDocument.Parse(body);
            if (doc.RootElement.TryGetProperty("error", out var prop))
                return prop.GetString() ?? body;
        }
        catch { /* fall through */ }
        return string.IsNullOrWhiteSpace(body) ? "error" : body;
    }

    // -------------------------------------------------------------------------
    // Email
    // -------------------------------------------------------------------------

    /// <summary>POST /send</summary>
    public Task<JsonElement> Email_SendAsync(object payload, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Post, "/send", payload, cancellationToken: ct);

    // -------------------------------------------------------------------------
    // Contacts
    // -------------------------------------------------------------------------

    /// <summary>GET /contacts</summary>
    public Task<JsonElement> Contacts_ListAsync(string? queryParams = null, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Get, queryParams is null ? "/contacts" : $"/contacts?{queryParams}", cancellationToken: ct);

    /// <summary>POST /contacts</summary>
    public Task<JsonElement> Contacts_CreateAsync(object payload, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Post, "/contacts", payload, cancellationToken: ct);

    /// <summary>GET /contacts/{id}</summary>
    public Task<JsonElement> Contacts_GetAsync(string id, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Get, $"/contacts/{id}", cancellationToken: ct);

    /// <summary>PATCH /contacts/{id}</summary>
    public Task<JsonElement> Contacts_UpdateAsync(string id, object payload, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Patch, $"/contacts/{id}", payload, cancellationToken: ct);

    /// <summary>DELETE /contacts/{id}</summary>
    public Task<JsonElement> Contacts_DeleteAsync(string id, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Delete, $"/contacts/{id}", cancellationToken: ct);

    /// <summary>POST /contacts/import</summary>
    public Task<JsonElement> Contacts_ImportContactsAsync(object payload, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Post, "/contacts/import", payload, cancellationToken: ct);

    // -------------------------------------------------------------------------
    // Campaigns
    // -------------------------------------------------------------------------

    /// <summary>GET /campaigns</summary>
    public Task<JsonElement> Campaigns_ListAsync(string? queryParams = null, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Get, queryParams is null ? "/campaigns" : $"/campaigns?{queryParams}", cancellationToken: ct);

    /// <summary>POST /campaigns</summary>
    public Task<JsonElement> Campaigns_CreateAsync(object payload, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Post, "/campaigns", payload, cancellationToken: ct);

    /// <summary>GET /campaigns/{id}</summary>
    public Task<JsonElement> Campaigns_GetAsync(string id, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Get, $"/campaigns/{id}", cancellationToken: ct);

    /// <summary>PATCH /campaigns/{id}</summary>
    public Task<JsonElement> Campaigns_UpdateAsync(string id, object payload, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Patch, $"/campaigns/{id}", payload, cancellationToken: ct);

    /// <summary>POST /campaigns/{id}/send</summary>
    public Task<JsonElement> Campaigns_SendCampaignAsync(string id, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Post, $"/campaigns/{id}/send", cancellationToken: ct);

    /// <summary>DELETE /campaigns/{id}</summary>
    public Task<JsonElement> Campaigns_DeleteAsync(string id, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Delete, $"/campaigns/{id}", cancellationToken: ct);

    // -------------------------------------------------------------------------
    // Templates
    // -------------------------------------------------------------------------

    /// <summary>GET /templates</summary>
    public Task<JsonElement> Templates_ListAsync(CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Get, "/templates", cancellationToken: ct);

    /// <summary>POST /templates</summary>
    public Task<JsonElement> Templates_CreateAsync(object payload, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Post, "/templates", payload, cancellationToken: ct);

    /// <summary>GET /templates/{id}</summary>
    public Task<JsonElement> Templates_GetAsync(string id, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Get, $"/templates/{id}", cancellationToken: ct);

    /// <summary>PATCH /templates/{id}</summary>
    public Task<JsonElement> Templates_UpdateAsync(string id, object payload, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Patch, $"/templates/{id}", payload, cancellationToken: ct);

    /// <summary>DELETE /templates/{id}</summary>
    public Task<JsonElement> Templates_DeleteAsync(string id, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Delete, $"/templates/{id}", cancellationToken: ct);

    /// <summary>POST /templates/render</summary>
    public Task<JsonElement> Templates_RenderAsync(object payload, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Post, "/templates/render", payload, cancellationToken: ct);

    // -------------------------------------------------------------------------
    // Automations
    // -------------------------------------------------------------------------

    /// <summary>GET /automations</summary>
    public Task<JsonElement> Automations_ListAsync(string? queryParams = null, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Get, queryParams is null ? "/automations" : $"/automations?{queryParams}", cancellationToken: ct);

    /// <summary>POST /automations</summary>
    public Task<JsonElement> Automations_CreateAsync(object payload, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Post, "/automations", payload, cancellationToken: ct);

    /// <summary>GET /automations/{id}</summary>
    public Task<JsonElement> Automations_GetAsync(string id, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Get, $"/automations/{id}", cancellationToken: ct);

    /// <summary>PATCH /automations/{id}</summary>
    public Task<JsonElement> Automations_UpdateAsync(string id, object payload, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Patch, $"/automations/{id}", payload, cancellationToken: ct);

    /// <summary>DELETE /automations/{id}</summary>
    public Task<JsonElement> Automations_DeleteAsync(string id, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Delete, $"/automations/{id}", cancellationToken: ct);

    /// <summary>POST /automations/{id}/activate</summary>
    public Task<JsonElement> Automations_ActivateAsync(string id, bool active, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Post, $"/automations/{id}/activate", new { active }, cancellationToken: ct);

    // -------------------------------------------------------------------------
    // Domains
    // -------------------------------------------------------------------------

    /// <summary>GET /domains</summary>
    public Task<JsonElement> Domains_ListAsync(CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Get, "/domains", cancellationToken: ct);

    /// <summary>POST /domains</summary>
    public Task<JsonElement> Domains_CreateAsync(object payload, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Post, "/domains", payload, cancellationToken: ct);

    /// <summary>GET /domains/{id}</summary>
    public Task<JsonElement> Domains_GetAsync(string id, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Get, $"/domains/{id}", cancellationToken: ct);

    /// <summary>POST /domains/{id}/verify</summary>
    public Task<JsonElement> Domains_VerifyAsync(string id, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Post, $"/domains/{id}/verify", cancellationToken: ct);

    /// <summary>DELETE /domains/{id}</summary>
    public Task<JsonElement> Domains_DeleteAsync(string id, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Delete, $"/domains/{id}", cancellationToken: ct);

    // -------------------------------------------------------------------------
    // Aliases
    // -------------------------------------------------------------------------

    /// <summary>GET /aliases</summary>
    public Task<JsonElement> Aliases_ListAsync(CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Get, "/aliases", cancellationToken: ct);

    /// <summary>POST /aliases</summary>
    public Task<JsonElement> Aliases_CreateAsync(object payload, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Post, "/aliases", payload, cancellationToken: ct);

    /// <summary>GET /aliases/{id}</summary>
    public Task<JsonElement> Aliases_GetAsync(string id, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Get, $"/aliases/{id}", cancellationToken: ct);

    /// <summary>PATCH /aliases/{id}</summary>
    public Task<JsonElement> Aliases_UpdateAsync(string id, object payload, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Patch, $"/aliases/{id}", payload, cancellationToken: ct);

    /// <summary>DELETE /aliases/{id}</summary>
    public Task<JsonElement> Aliases_DeleteAsync(string id, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Delete, $"/aliases/{id}", cancellationToken: ct);

    // -------------------------------------------------------------------------
    // Dedicated IPs
    // -------------------------------------------------------------------------

    /// <summary>GET /dedicated-ips</summary>
    public Task<JsonElement> DedicatedIPs_ListAsync(CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Get, "/dedicated-ips", cancellationToken: ct);

    /// <summary>POST /dedicated-ips</summary>
    public Task<JsonElement> DedicatedIPs_CreateAsync(object payload, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Post, "/dedicated-ips", payload, cancellationToken: ct);

    /// <summary>PATCH /dedicated-ips/{id}</summary>
    public Task<JsonElement> DedicatedIPs_UpdateAsync(string id, object payload, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Patch, $"/dedicated-ips/{id}", payload, cancellationToken: ct);

    /// <summary>DELETE /dedicated-ips/{id}</summary>
    public Task<JsonElement> DedicatedIPs_DeleteAsync(string id, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Delete, $"/dedicated-ips/{id}", cancellationToken: ct);

    // -------------------------------------------------------------------------
    // Channels
    // -------------------------------------------------------------------------

    /// <summary>POST /channels/whatsapp</summary>
    public Task<JsonElement> Channels_SendWhatsAppAsync(object payload, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Post, "/channels/whatsapp", payload, cancellationToken: ct);

    /// <summary>POST /channels/push</summary>
    public Task<JsonElement> Channels_SendPushAsync(object payload, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Post, "/channels/push", payload, cancellationToken: ct);

    // -------------------------------------------------------------------------
    // A/B Tests
    // -------------------------------------------------------------------------

    /// <summary>GET /ab-tests</summary>
    public Task<JsonElement> AbTests_ListAsync(CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Get, "/ab-tests", cancellationToken: ct);

    /// <summary>POST /ab-tests</summary>
    public Task<JsonElement> AbTests_CreateAsync(object payload, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Post, "/ab-tests", payload, cancellationToken: ct);

    /// <summary>GET /ab-tests/{id}</summary>
    public Task<JsonElement> AbTests_GetAsync(string id, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Get, $"/ab-tests/{id}", cancellationToken: ct);

    /// <summary>POST /ab-tests/{id}/winner</summary>
    public Task<JsonElement> AbTests_SetWinnerAsync(string id, string variantId, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Post, $"/ab-tests/{id}/winner", new { variantId }, cancellationToken: ct);

    // -------------------------------------------------------------------------
    // Sandbox
    // -------------------------------------------------------------------------

    /// <summary>POST /sandbox/send</summary>
    public Task<JsonElement> Sandbox_SendAsync(object payload, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Post, "/sandbox/send", payload, cancellationToken: ct);

    /// <summary>GET /sandbox</summary>
    public Task<JsonElement> Sandbox_ListAsync(string? queryParams = null, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Get, queryParams is null ? "/sandbox" : $"/sandbox?{queryParams}", cancellationToken: ct);

    /// <summary>DELETE /sandbox/{id}</summary>
    public Task<JsonElement> Sandbox_DeleteAsync(string id, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Delete, $"/sandbox/{id}", cancellationToken: ct);

    // -------------------------------------------------------------------------
    // Inbound
    // -------------------------------------------------------------------------

    /// <summary>GET /inbound</summary>
    public Task<JsonElement> Inbound_ListAsync(string? queryParams = null, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Get, queryParams is null ? "/inbound" : $"/inbound?{queryParams}", cancellationToken: ct);

    /// <summary>POST /inbound</summary>
    public Task<JsonElement> Inbound_CreateAsync(object payload, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Post, "/inbound", payload, cancellationToken: ct);

    /// <summary>GET /inbound/{id}</summary>
    public Task<JsonElement> Inbound_GetAsync(string id, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Get, $"/inbound/{id}", cancellationToken: ct);

    /// <summary>DELETE /inbound/{id}</summary>
    public Task<JsonElement> Inbound_DeleteAsync(string id, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Delete, $"/inbound/{id}", cancellationToken: ct);

    // -------------------------------------------------------------------------
    // Analytics
    // -------------------------------------------------------------------------

    /// <summary>GET /analytics</summary>
    public Task<JsonElement> Analytics_OverviewAsync(string? queryParams = null, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Get, queryParams is null ? "/analytics" : $"/analytics?{queryParams}", cancellationToken: ct);

    // -------------------------------------------------------------------------
    // Track
    // -------------------------------------------------------------------------

    /// <summary>POST /track/event</summary>
    public Task<JsonElement> Track_EventAsync(object payload, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Post, "/track/event", payload, cancellationToken: ct);

    /// <summary>POST /track/purchase</summary>
    public Task<JsonElement> Track_PurchaseAsync(object payload, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Post, "/track/purchase", payload, cancellationToken: ct);

    // -------------------------------------------------------------------------
    // API Keys
    // -------------------------------------------------------------------------

    /// <summary>GET /keys</summary>
    public Task<JsonElement> Keys_ListAsync(CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Get, "/keys", cancellationToken: ct);

    /// <summary>POST /keys</summary>
    public Task<JsonElement> Keys_CreateAsync(object payload, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Post, "/keys", payload, cancellationToken: ct);

    /// <summary>GET /keys/{id}</summary>
    public Task<JsonElement> Keys_GetAsync(string id, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Get, $"/keys/{id}", cancellationToken: ct);

    /// <summary>DELETE /keys/{id}</summary>
    public Task<JsonElement> Keys_RevokeAsync(string id, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Delete, $"/keys/{id}", cancellationToken: ct);

    // -------------------------------------------------------------------------
    // Validate
    // -------------------------------------------------------------------------

    /// <summary>POST /validate</summary>
    public Task<JsonElement> Validate_EmailAsync(string address, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Post, "/validate", new { email = address }, cancellationToken: ct);

    // -------------------------------------------------------------------------
    // Leads
    // -------------------------------------------------------------------------

    /// <summary>POST /leads/search</summary>
    public Task<JsonElement> Leads_SearchAsync(object payload, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Post, "/leads/search", payload, cancellationToken: ct);

    /// <summary>GET /leads/jobs/{id}</summary>
    public Task<JsonElement> Leads_GetJobAsync(string id, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Get, $"/leads/jobs/{id}", cancellationToken: ct);

    /// <summary>GET /leads/jobs</summary>
    public Task<JsonElement> Leads_ListJobsAsync(string? queryParams = null, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Get, queryParams is null ? "/leads/jobs" : $"/leads/jobs?{queryParams}", cancellationToken: ct);

    /// <summary>GET /leads/jobs/{jobId}/results</summary>
    public Task<JsonElement> Leads_ResultsAsync(string jobId, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Get, $"/leads/jobs/{jobId}/results", cancellationToken: ct);

    /// <summary>POST /leads/import</summary>
    public Task<JsonElement> Leads_ImportLeadsAsync(object payload, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Post, "/leads/import", payload, cancellationToken: ct);

    /// <summary>GET /leads/credits</summary>
    public Task<JsonElement> Leads_CreditsAsync(CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Get, "/leads/credits", cancellationToken: ct);

    // -------------------------------------------------------------------------
    // Autopilot
    // -------------------------------------------------------------------------

    /// <summary>POST /autopilot</summary>
    public Task<JsonElement> Autopilot_StartAsync(object payload, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Post, "/autopilot", payload, cancellationToken: ct);

    /// <summary>GET /autopilot/{id}</summary>
    public Task<JsonElement> Autopilot_GetAsync(string id, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Get, $"/autopilot/{id}", cancellationToken: ct);

    /// <summary>GET /autopilot</summary>
    public Task<JsonElement> Autopilot_ListAsync(string? queryParams = null, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Get, queryParams is null ? "/autopilot" : $"/autopilot?{queryParams}", cancellationToken: ct);

    /// <summary>GET /autopilot/daily-plan</summary>
    public Task<JsonElement> Autopilot_DailyPlanAsync(CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Get, "/autopilot/daily-plan", cancellationToken: ct);

    // -------------------------------------------------------------------------
    // Sales Agent
    // -------------------------------------------------------------------------

    /// <summary>GET /sales-agent/config</summary>
    public Task<JsonElement> SalesAgent_GetConfigAsync(CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Get, "/sales-agent/config", cancellationToken: ct);

    /// <summary>PATCH /sales-agent/config</summary>
    public Task<JsonElement> SalesAgent_UpdateConfigAsync(object payload, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Patch, "/sales-agent/config", payload, cancellationToken: ct);

    /// <summary>GET /sales-agent/actions</summary>
    public Task<JsonElement> SalesAgent_GetActionsAsync(string? queryParams = null, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Get, queryParams is null ? "/sales-agent/actions" : $"/sales-agent/actions?{queryParams}", cancellationToken: ct);

    // -------------------------------------------------------------------------
    // CRM
    // -------------------------------------------------------------------------

    /// <summary>GET /crm/conversations</summary>
    public Task<JsonElement> CRM_ListConversationsAsync(string? queryParams = null, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Get, queryParams is null ? "/crm/conversations" : $"/crm/conversations?{queryParams}", cancellationToken: ct);

    /// <summary>GET /crm/conversations/{id}</summary>
    public Task<JsonElement> CRM_GetConversationAsync(string id, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Get, $"/crm/conversations/{id}", cancellationToken: ct);

    /// <summary>PATCH /crm/conversations/{id}</summary>
    public Task<JsonElement> CRM_UpdateConversationAsync(string id, object payload, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Patch, $"/crm/conversations/{id}", payload, cancellationToken: ct);

    /// <summary>GET /crm/conversations/{conversationId}/messages</summary>
    public Task<JsonElement> CRM_ListMessagesAsync(string conversationId, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Get, $"/crm/conversations/{conversationId}/messages", cancellationToken: ct);

    /// <summary>GET /crm/deals</summary>
    public Task<JsonElement> CRM_ListDealsAsync(string? queryParams = null, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Get, queryParams is null ? "/crm/deals" : $"/crm/deals?{queryParams}", cancellationToken: ct);

    /// <summary>POST /crm/deals</summary>
    public Task<JsonElement> CRM_CreateDealAsync(object payload, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Post, "/crm/deals", payload, cancellationToken: ct);

    /// <summary>GET /crm/deals/{id}</summary>
    public Task<JsonElement> CRM_GetDealAsync(string id, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Get, $"/crm/deals/{id}", cancellationToken: ct);

    /// <summary>PATCH /crm/deals/{id}</summary>
    public Task<JsonElement> CRM_UpdateDealAsync(string id, object payload, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Patch, $"/crm/deals/{id}", payload, cancellationToken: ct);

    /// <summary>DELETE /crm/deals/{id}</summary>
    public Task<JsonElement> CRM_DeleteDealAsync(string id, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Delete, $"/crm/deals/{id}", cancellationToken: ct);

    /// <summary>GET /crm/clients</summary>
    public Task<JsonElement> CRM_ListClientsAsync(string? queryParams = null, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Get, queryParams is null ? "/crm/clients" : $"/crm/clients?{queryParams}", cancellationToken: ct);

    /// <summary>POST /crm/clients</summary>
    public Task<JsonElement> CRM_CreateClientAsync(object payload, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Post, "/crm/clients", payload, cancellationToken: ct);

    // -------------------------------------------------------------------------
    // Webhooks
    // -------------------------------------------------------------------------

    /// <summary>GET /webhooks</summary>
    public Task<JsonElement> Webhooks_ListAsync(CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Get, "/webhooks", cancellationToken: ct);

    /// <summary>POST /webhooks</summary>
    public Task<JsonElement> Webhooks_CreateAsync(object payload, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Post, "/webhooks", payload, cancellationToken: ct);

    /// <summary>GET /webhooks/{id}</summary>
    public Task<JsonElement> Webhooks_GetAsync(string id, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Get, $"/webhooks/{id}", cancellationToken: ct);

    /// <summary>PATCH /webhooks/{id}</summary>
    public Task<JsonElement> Webhooks_UpdateAsync(string id, object payload, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Patch, $"/webhooks/{id}", payload, cancellationToken: ct);

    /// <summary>DELETE /webhooks/{id}</summary>
    public Task<JsonElement> Webhooks_DeleteAsync(string id, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Delete, $"/webhooks/{id}", cancellationToken: ct);

    /// <summary>POST /webhooks/{id}/test</summary>
    public Task<JsonElement> Webhooks_TestAsync(string id, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Post, $"/webhooks/{id}/test", cancellationToken: ct);

    // -------------------------------------------------------------------------
    // Usage
    // -------------------------------------------------------------------------

    /// <summary>GET /usage</summary>
    public Task<JsonElement> Usage_GetAsync(string? queryParams = null, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Get, queryParams is null ? "/usage" : $"/usage?{queryParams}", cancellationToken: ct);

    // -------------------------------------------------------------------------
    // Billing  (apiBase — no /v1)
    // -------------------------------------------------------------------------

    /// <summary>GET {apiBase}/billing/subscription</summary>
    public Task<JsonElement> Billing_SubscriptionAsync(CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Get, "/billing/subscription", useApiBase: true, cancellationToken: ct);

    /// <summary>POST {apiBase}/billing/checkout</summary>
    public Task<JsonElement> Billing_CheckoutAsync(object payload, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Post, "/billing/checkout", payload, useApiBase: true, cancellationToken: ct);

    // -------------------------------------------------------------------------
    // Workspaces  (apiBase — no /v1)
    // -------------------------------------------------------------------------

    /// <summary>GET {apiBase}/workspaces</summary>
    public Task<JsonElement> Workspaces_ListAsync(CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Get, "/workspaces", useApiBase: true, cancellationToken: ct);

    /// <summary>POST {apiBase}/workspaces</summary>
    public Task<JsonElement> Workspaces_CreateAsync(object payload, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Post, "/workspaces", payload, useApiBase: true, cancellationToken: ct);

    /// <summary>GET {apiBase}/workspaces/{id}</summary>
    public Task<JsonElement> Workspaces_GetAsync(string id, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Get, $"/workspaces/{id}", useApiBase: true, cancellationToken: ct);

    /// <summary>PATCH {apiBase}/workspaces/{id}</summary>
    public Task<JsonElement> Workspaces_UpdateAsync(string id, object payload, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Patch, $"/workspaces/{id}", payload, useApiBase: true, cancellationToken: ct);

    /// <summary>DELETE {apiBase}/workspaces/{id}</summary>
    public Task<JsonElement> Workspaces_DeleteAsync(string id, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Delete, $"/workspaces/{id}", useApiBase: true, cancellationToken: ct);

    /// <summary>GET {apiBase}/workspaces/{wsId}/members</summary>
    public Task<JsonElement> Workspaces_ListMembersAsync(string wsId, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Get, $"/workspaces/{wsId}/members", useApiBase: true, cancellationToken: ct);

    /// <summary>POST {apiBase}/workspaces/{wsId}/members</summary>
    public Task<JsonElement> Workspaces_InviteMemberAsync(string wsId, object payload, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Post, $"/workspaces/{wsId}/members", payload, useApiBase: true, cancellationToken: ct);

    /// <summary>PATCH {apiBase}/workspaces/{wsId}/members/{userId}</summary>
    public Task<JsonElement> Workspaces_UpdateMemberAsync(string wsId, string userId, object payload, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Patch, $"/workspaces/{wsId}/members/{userId}", payload, useApiBase: true, cancellationToken: ct);

    /// <summary>DELETE {apiBase}/workspaces/{wsId}/members/{userId}</summary>
    public Task<JsonElement> Workspaces_RemoveMemberAsync(string wsId, string userId, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Delete, $"/workspaces/{wsId}/members/{userId}", useApiBase: true, cancellationToken: ct);

    // -------------------------------------------------------------------------
    // IDisposable
    // -------------------------------------------------------------------------

    public void Dispose()
    {
        if (_ownsHttpClient)
            _httpClient.Dispose();
    }
}
