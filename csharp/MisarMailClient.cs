using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;

namespace MisarMail;

/// <summary>
/// MisarMail API client (C# 10+, System.Text.Json).
///
/// All methods perform up to <see cref="MaxRetries"/> attempts with
/// exponential back-off (starting at 500 ms) on retryable HTTP statuses
/// (429, 500, 502, 503, 504).
/// </summary>
public sealed partial class MisarMailClient : IDisposable
{
    /// <summary>
    /// Renders <c>?a=b&amp;c=d</c> for the pairs that are set. Used by the
    /// generated members; returns "" when every value is null.
    /// </summary>
    private static string BuildQuery(params (string Name, string? Value)[] pairs)
    {
        var parts = new List<string>();
        foreach (var (name, value) in pairs)
        {
            if (value is null) continue;
            parts.Add($"{Uri.EscapeDataString(name)}={Uri.EscapeDataString(value)}");
        }
        return parts.Count == 0 ? "" : "?" + string.Join("&", parts);
    }

    private static readonly HashSet<int> RetryableStatuses = [429, 500, 502, 503, 504];

    /// <summary>True when the body carries the API's plan-refusal marker.</summary>
    private static bool IsPlanLimit(string body)
    {
        if (string.IsNullOrWhiteSpace(body)) return false;
        try
        {
            using var doc = JsonDocument.Parse(body);
            var root = doc.RootElement;
            if (root.ValueKind != JsonValueKind.Object) return false;
            if (root.TryGetProperty("code", out var c) && c.ValueKind == JsonValueKind.String
                && c.GetString() == "plan_limit_exceeded") return true;
            if (root.TryGetProperty("error_type", out var t) && t.ValueKind == JsonValueKind.String
                && t.GetString() == "plan_limit_exceeded") return true;
            return root.TryGetProperty("upgrade", out var u) && u.ValueKind == JsonValueKind.Object;
        }
        catch { return false; }
    }

    private static MisarMailPlanLimitException BuildPlanLimitError(
        int status, string body, HttpResponseMessage response)
    {
        string message = "plan limit exceeded";
        string? plan = null, upgradeUrl = null, feature = null;

        try
        {
            using var doc = JsonDocument.Parse(body);
            var root = doc.RootElement;
            if (root.TryGetProperty("error", out var e) && e.ValueKind == JsonValueKind.String)
                message = e.GetString() ?? message;

            if (root.TryGetProperty("upgrade", out var offer) && offer.ValueKind == JsonValueKind.Object)
            {
                if (offer.TryGetProperty("currentPlanSlug", out var ps) && ps.ValueKind == JsonValueKind.String)
                    plan = ps.GetString();
                else if (offer.TryGetProperty("current_plan", out var cp)
                         && cp.TryGetProperty("slug", out var slug) && slug.ValueKind == JsonValueKind.String)
                    plan = slug.GetString();

                if (offer.TryGetProperty("urls", out var urls)
                    && urls.TryGetProperty("pricing", out var pr) && pr.ValueKind == JsonValueKind.String)
                    upgradeUrl = pr.GetString();

                if (offer.TryGetProperty("feature", out var f) && f.ValueKind == JsonValueKind.String)
                    feature = f.GetString();
            }
        }
        catch { /* non-JSON body — headers below are the only source */ }

        // Headers are authoritative; the offer body is the fallback when a
        // proxy has stripped them.
        if (response.Headers.TryGetValues("X-Misar-Plan", out var ph))
            plan = System.Linq.Enumerable.FirstOrDefault(ph) ?? plan;
        if (response.Headers.TryGetValues("X-Misar-Upgrade-Url", out var uh))
            upgradeUrl = System.Linq.Enumerable.FirstOrDefault(uh) ?? upgradeUrl;

        int? retryAfter = null;
        if (response.Headers.TryGetValues("Retry-After", out var ra)
            && int.TryParse(System.Linq.Enumerable.FirstOrDefault(ra), out var secs))
            retryAfter = secs;

        return new MisarMailPlanLimitException(status, message, plan, upgradeUrl, retryAfter, feature);
    }

    private readonly string _apiKey;
    private readonly string _baseUrl;
    private readonly string _apiBase;   // billing/workspaces — no /v1
    private readonly int _maxRetries;
    private readonly HttpClient _httpClient;
    private readonly bool _ownsHttpClient;

    public int MaxRetries => _maxRetries;

    public MisarMailClient(
        string apiKey,
        string baseUrl = "https://api.misar.io/mail/v1",
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

                string responseBody = await response.Content
                    .ReadAsStringAsync(cancellationToken).ConfigureAwait(false);

                // A rate-limit 429 and a spent-allowance 429 are identical by
                // status, so the body decides. Only the first is worth retrying.
                if (IsPlanLimit(responseBody))
                    throw BuildPlanLimitError(status, responseBody, response);

                if (RetryableStatuses.Contains(status) && attempt < _maxRetries - 1)
                {
                    lastException = new MisarMailException(status, "retryable error");
                    continue;
                }

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

    /// <summary>GET /contacts?id=&lt;uuid&gt; — query parameter, not a path segment.</summary>
    public Task<JsonElement> Contacts_GetAsync(string id, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Get, $"/contacts?id={Uri.EscapeDataString(id)}", cancellationToken: ct);

    /// <summary>PATCH /contacts — the contact is identified by <c>email</c> in the body.</summary>
    public Task<JsonElement> Contacts_UpdateAsync(string email, object payload, CancellationToken ct = default)
    {
        // The route identifies the contact by `email` in the body — not by an id
        // and not by a path segment. Merging here keeps the caller's payload
        // shape while guaranteeing the field the schema requires is present.
        var merged = new Dictionary<string, object?>();
        foreach (var prop in JsonSerializer.SerializeToElement(payload).EnumerateObject())
            merged[prop.Name] = prop.Value;
        merged["email"] = email;
        return RequestAsync(HttpMethod.Patch, "/contacts", merged, cancellationToken: ct);
    }

    /// <summary>DELETE /contacts?id=&lt;uuid&gt; — query parameter, not a path segment.</summary>
    public Task<JsonElement> Contacts_DeleteAsync(string id, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Delete, $"/contacts?id={Uri.EscapeDataString(id)}", cancellationToken: ct);

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
        RequestAsync(HttpMethod.Get, "/domains", useApiBase: true, cancellationToken: ct);

    /// <summary>POST /domains</summary>
    public Task<JsonElement> Domains_CreateAsync(object payload, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Post, "/domains", payload, useApiBase: true, cancellationToken: ct);

    /// <summary>GET /domains/{id}</summary>
    public Task<JsonElement> Domains_GetAsync(string id, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Get, $"/domains/{id}", useApiBase: true, cancellationToken: ct);

    /// <summary>POST /domains/{id}/verify</summary>
    public Task<JsonElement> Domains_VerifyAsync(string id, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Post, $"/domains/{id}/verify", useApiBase: true, cancellationToken: ct);

    /// <summary>DELETE /domains/{id}</summary>
    public Task<JsonElement> Domains_DeleteAsync(string id, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Delete, $"/domains/{id}", useApiBase: true, cancellationToken: ct);






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
    // IDisposable
    // -------------------------------------------------------------------------

    public void Dispose()
    {
        if (_ownsHttpClient)
            _httpClient.Dispose();
    }

    // =========================================================================
    // Plan — live subscription standing for the key's owner
    // =========================================================================

    /// <summary>
    /// GET /plan — plan, sending allowances, per-feature usage and the upgrade
    /// offer. Read this before an expensive call rather than discovering the
    /// ceiling through a <see cref="MisarMailPlanLimitException"/>.
    /// </summary>
    public Task<JsonElement> Plan_GetAsync(CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Get, "/plan", cancellationToken: ct);

    /// <summary>GET /monetization/stats — revenue and monetization counters.</summary>
    public Task<JsonElement> Plan_MonetizationAsync(CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Get, "/monetization/stats", cancellationToken: ct);

    // =========================================================================
    // Generated from scripts/sdk-endpoint-spec.json
    //
    // These twenty endpoints were missing from every SDK except TypeScript.
    // The flat Group_MethodAsync naming matches the hand-written members.
    // =========================================================================

    /// <summary>POST /ai/subject-lines</summary>
    public Task<JsonElement> Ai_SubjectLinesAsync(object? body = null, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Post, "/ai/subject-lines", body, cancellationToken: ct);

    /// <summary>GET /credit-rates</summary>
    public Task<JsonElement> CreditRates_ListAsync(CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Get, "/credit-rates", cancellationToken: ct);

    /// <summary>GET /deliverability/audit</summary>
    public Task<JsonElement> Deliverability_AuditAsync(CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Get, "/deliverability/audit", cancellationToken: ct);

    /// <summary>GET /deliverability/score</summary>
    public Task<JsonElement> Deliverability_ScoreAsync(CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Get, "/deliverability/score", cancellationToken: ct);

    /// <summary>GET /dmarc/check</summary>
    public Task<JsonElement> Dmarc_CheckAsync(string? domain = null, string? dkim_selector = null, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Get, "/dmarc/check" + BuildQuery(("domain", domain), ("dkim_selector", dkim_selector)), cancellationToken: ct);

    /// <summary>GET /dmarc/domains</summary>
    public Task<JsonElement> Dmarc_ListDomainsAsync(CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Get, "/dmarc/domains", cancellationToken: ct);

    /// <summary>POST /dmarc/domains</summary>
    public Task<JsonElement> Dmarc_AddDomainAsync(object? body = null, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Post, "/dmarc/domains", body, cancellationToken: ct);

    /// <summary>DELETE /dmarc/domains</summary>
    public Task<JsonElement> Dmarc_RemoveDomainAsync(string? domain_id = null, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Delete, "/dmarc/domains" + BuildQuery(("domain_id", domain_id)), cancellationToken: ct);

    /// <summary>GET /email-accounts</summary>
    public Task<JsonElement> EmailAccounts_ListAsync(CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Get, "/email-accounts", cancellationToken: ct);

    /// <summary>GET /emails</summary>
    public Task<JsonElement> Emails_ListAsync(string? folder = null, string? search = null, int? limit = null, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Get, "/emails" + BuildQuery(("folder", folder), ("search", search), ("limit", limit?.ToString())), cancellationToken: ct);

    /// <summary>GET /emails/:id</summary>
    public Task<JsonElement> Emails_GetAsync(string id, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Get, "/emails/" + Uri.EscapeDataString(id), cancellationToken: ct);

    /// <summary>PATCH /emails/:id</summary>
    public Task<JsonElement> Emails_UpdateAsync(string id, object? body = null, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Patch, "/emails/" + Uri.EscapeDataString(id), body, cancellationToken: ct);

    /// <summary>POST /landing-pages</summary>
    public Task<JsonElement> LandingPages_CreateAsync(object? body = null, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Post, "/landing-pages", body, cancellationToken: ct);

    /// <summary>POST /monetization/tip</summary>
    public Task<JsonElement> Monetization_TipAsync(object? body = null, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Post, "/monetization/tip", body, cancellationToken: ct);

    /// <summary>GET /plan-limits</summary>
    public Task<JsonElement> Plan_LimitsAsync(string? product = null, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Get, "/plan-limits" + BuildQuery(("product", product)), cancellationToken: ct);

    /// <summary>GET /revenue/attribution</summary>
    public Task<JsonElement> Revenue_AttributionAsync(string? campaign_id = null, string? period = null, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Get, "/revenue/attribution" + BuildQuery(("campaign_id", campaign_id), ("period", period)), cancellationToken: ct);

    /// <summary>GET /segments/:id/members</summary>
    public Task<JsonElement> Segments_MembersAsync(string id, int? page = null, int? limit = null, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Get, "/segments/" + Uri.EscapeDataString(id) + "/members" + BuildQuery(("page", page?.ToString()), ("limit", limit?.ToString())), cancellationToken: ct);

    /// <summary>GET /subscription</summary>
    public Task<JsonElement> Subscription_GetAsync(string? product = null, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Get, "/subscription" + BuildQuery(("product", product)), cancellationToken: ct);

    /// <summary>POST /subscription</summary>
    public Task<JsonElement> Subscription_UpsertAsync(object? body = null, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Post, "/subscription", body, cancellationToken: ct);

    /// <summary>DELETE /subscription</summary>
    public Task<JsonElement> Subscription_CancelAsync(object? body = null, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Delete, "/subscription", body, cancellationToken: ct);

    /// <summary>GET /team-members</summary>
    public Task<JsonElement> TeamMembers_GetAsync(string? owner_id = null, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Get, "/team-members" + BuildQuery(("owner_id", owner_id)), cancellationToken: ct);

    /// <summary>GET /wallet</summary>
    public Task<JsonElement> Wallet_GetAsync(CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Get, "/wallet", cancellationToken: ct);

    /// <summary>POST /wallet/credit</summary>
    public Task<JsonElement> Wallet_CreditAsync(object? body = null, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Post, "/wallet/credit", body, cancellationToken: ct);

    /// <summary>POST /wallet/debit</summary>
    public Task<JsonElement> Wallet_DebitAsync(object? body = null, CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Post, "/wallet/debit", body, cancellationToken: ct);

    /// <summary>GET /warmup</summary>
    public Task<JsonElement> Warmup_GetAsync(CancellationToken ct = default) =>
        RequestAsync(HttpMethod.Get, "/warmup", cancellationToken: ct);
}
