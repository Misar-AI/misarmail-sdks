using System.Net;
using System.Text;
using System.Text.Json;
using MisarMail;
using Xunit;

namespace Misar.Mail.Tests;

/// <summary>
/// Unit tests for <see cref="MisarMailClient"/>.
///
/// A stub <see cref="HttpMessageHandler"/> replaces the transport, so the real
/// request/retry/error code runs but no network call is made. The streaming
/// tests push the response body through in pieces on purpose, so a frame
/// boundary lands mid-chunk and the buffering is actually exercised.
/// </summary>
public sealed class MisarMailClientTests
{
    // -------------------------------------------------------------------------
    // Stubs
    // -------------------------------------------------------------------------

    /// <summary>Replays a fixed queue of responses, one per request.</summary>
    private sealed class ScriptedHandler : HttpMessageHandler
    {
        private readonly Queue<(int Status, string Body, (string, string)[] Headers)> _queue;

        public int Requests { get; private set; }

        public ScriptedHandler(params (int Status, string Body, (string, string)[] Headers)[] responses)
        {
            _queue = new Queue<(int, string, (string, string)[])>(responses);
        }

        protected override Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request, CancellationToken cancellationToken)
        {
            Requests++;
            var (status, body, headers) = _queue.Count > 0
                ? _queue.Dequeue()
                : (500, "{\"error\":\"script exhausted\"}", Array.Empty<(string, string)>());

            var response = new HttpResponseMessage((HttpStatusCode)status)
            {
                Content = new StringContent(body, Encoding.UTF8, "application/json")
            };
            foreach (var (name, value) in headers)
                response.Headers.TryAddWithoutValidation(name, value);

            return Task.FromResult(response);
        }
    }

    /// <summary>Streams the given pieces as one <c>text/event-stream</c> body.</summary>
    private sealed class SseHandler : HttpMessageHandler
    {
        private readonly string[] _pieces;
        private readonly int _status;
        private readonly string? _errorBody;
        private readonly (string, string)[] _headers;

        public SseHandler(params string[] pieces)
        {
            _pieces = pieces;
            _status = 200;
            _headers = Array.Empty<(string, string)>();
        }

        public SseHandler(int status, string errorBody, params (string, string)[] headers)
        {
            _pieces = Array.Empty<string>();
            _status = status;
            _errorBody = errorBody;
            _headers = headers;
        }

        protected override async Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request, CancellationToken cancellationToken)
        {
            await Task.Yield();

            if (_errorBody is not null)
            {
                var refused = new HttpResponseMessage((HttpStatusCode)_status)
                {
                    Content = new StringContent(_errorBody, Encoding.UTF8, "application/json")
                };
                foreach (var (name, value) in _headers)
                    refused.Headers.TryAddWithoutValidation(name, value);
                return refused;
            }

            var stream = new MemoryStream();
            foreach (var piece in _pieces)
            {
                var bytes = Encoding.UTF8.GetBytes(piece);
                stream.Write(bytes, 0, bytes.Length);
            }
            stream.Position = 0;

            var response = new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StreamContent(stream)
            };
            response.Content.Headers.TryAddWithoutValidation("Content-Type", "text/event-stream");
            return response;
        }
    }

    private static MisarMailClient ClientWith(HttpMessageHandler handler, int maxRetries = 1) =>
        new(apiKey: "test-key", maxRetries: maxRetries, httpClient: new HttpClient(handler));

    private static MisarMailClient ClientWith(int status, string body) =>
        ClientWith(new ScriptedHandler((status, body, Array.Empty<(string, string)>())));

    // -------------------------------------------------------------------------
    // REST
    // -------------------------------------------------------------------------

    [Fact]
    public async Task EmailSend_200_ReturnsParsedResponse()
    {
        var client = ClientWith(200, "{\"success\":true,\"message_id\":\"msg_123\"}");
        var result = await client.Email_SendAsync(new { from = "a@b.com", to = new[] { "c@d.com" } });

        Assert.True(result.GetProperty("success").GetBoolean());
        Assert.Equal("msg_123", result.GetProperty("message_id").GetString());
    }

    [Fact]
    public async Task ContactsList_200_ReturnsData()
    {
        var client = ClientWith(200, "{\"data\":[{\"id\":\"c1\",\"email\":\"a@b.com\"}],\"total\":1}");
        var result = await client.Contacts_ListAsync();

        Assert.Equal(1, result.GetProperty("total").GetInt32());
        Assert.Equal("a@b.com", result.GetProperty("data")[0].GetProperty("email").GetString());
    }

    [Fact]
    public async Task PlanGet_ReportsTheSubscriptionBehindTheKey()
    {
        var client = ClientWith(200, "{\"plan\":{\"slug\":\"pro\"},\"limits\":{\"emails_per_month\":50000}}");
        var result = await client.Plan_GetAsync();

        Assert.Equal("pro", result.GetProperty("plan").GetProperty("slug").GetString());
        Assert.Equal(50000, result.GetProperty("limits").GetProperty("emails_per_month").GetInt32());
    }

    [Fact]
    public async Task Unauthorized_ThrowsWithStatus()
    {
        var client = ClientWith(401, "{\"error\":\"unauthorized\"}");
        var ex = await Assert.ThrowsAsync<MisarMailException>(() => client.Contacts_ListAsync());

        Assert.Equal(401, ex.Status);
        Assert.Contains("unauthorized", ex.Message);
    }

    [Fact]
    public async Task ValidateEmail_200_ReturnsVerdict()
    {
        var client = ClientWith(200, "{\"valid\":true,\"disposable\":false}");
        var result = await client.Validate_EmailAsync("user@example.com");

        Assert.True(result.GetProperty("valid").GetBoolean());
        Assert.False(result.GetProperty("disposable").GetBoolean());
    }

    [Fact]
    public async Task Retries503ThenSucceeds()
    {
        var handler = new ScriptedHandler(
            (503, "{\"error\":\"unavailable\"}", Array.Empty<(string, string)>()),
            (503, "{\"error\":\"unavailable\"}", Array.Empty<(string, string)>()),
            (200, "{\"data\":[{\"id\":\"t1\"}]}", Array.Empty<(string, string)>()));

        var client = ClientWith(handler, maxRetries: 3);
        var result = await client.Templates_ListAsync();

        Assert.Equal("t1", result.GetProperty("data")[0].GetProperty("id").GetString());
        Assert.Equal(3, handler.Requests);
    }

    // -------------------------------------------------------------------------
    // Plan limits
    // -------------------------------------------------------------------------

    [Fact]
    public async Task SpentAllowance_ThrowsPlanLimitAndIsNotRetried()
    {
        const string body = """
        {"code":"plan_limit_exceeded","error":"monthly campaign allowance spent",
         "upgrade":{"feature":"campaigns","currentPlanSlug":"starter",
                    "urls":{"pricing":"https://misarmail.com/pricing"}}}
        """;
        var handler = new ScriptedHandler(
            (429, body, new[] { ("X-Misar-Plan", "starter"), ("Retry-After", "3600") }));

        // maxRetries 3 so that a plain retryable 429 would have been retried.
        var client = ClientWith(handler, maxRetries: 3);
        var ex = await Assert.ThrowsAsync<MisarMailPlanLimitException>(
            () => client.Campaigns_CreateAsync(new { name = "Blast" }));

        Assert.Equal(429, ex.Status);
        Assert.Equal("starter", ex.Plan);
        Assert.Equal("campaigns", ex.Feature);
        Assert.Equal(3600, ex.RetryAfter);
        Assert.Equal("https://misarmail.com/pricing", ex.UpgradeUrl);

        // A spent allowance cannot be fixed by retrying, so exactly one request.
        Assert.Equal(1, handler.Requests);
    }

    [Fact]
    public async Task FeatureNotOnPlan_Throws402PlanLimit()
    {
        const string body = """
        {"code":"plan_limit_exceeded","error":"dedicated IPs are not on your plan",
         "upgrade":{"feature":"dedicated_ips","urls":{"pricing":"https://misarmail.com/pricing"}}}
        """;
        var client = ClientWith(new ScriptedHandler((402, body, Array.Empty<(string, string)>())));
        var ex = await Assert.ThrowsAsync<MisarMailPlanLimitException>(
            () => client.DedicatedIPs_ListAsync());

        Assert.Equal(402, ex.Status);
        Assert.Equal("dedicated_ips", ex.Feature);
    }

    // -------------------------------------------------------------------------
    // Server-Sent Events
    // -------------------------------------------------------------------------

    [Fact]
    public async Task GenerateEmail_YieldsEachFrame()
    {
        // The frame boundary is deliberately split across two pieces.
        var client = ClientWith(new SseHandler(
            "data: {\"delta\":\"Hel\"}\n",
            "\ndata: {\"delta\":\"lo\"}\n\n",
            ": keepalive\n\n",
            "data: {\"delta\":\"!\"}\n\n",
            "data: [DONE]\n\n"));

        var deltas = new List<string>();
        await foreach (var e in client.Streaming_GenerateEmailAsync(new { prompt = "hi" }))
            deltas.Add(e.Data!.Value.GetProperty("delta").GetString()!);

        Assert.Equal(new[] { "Hel", "lo", "!" }, deltas);
    }

    [Fact]
    public async Task Stream_StopsAtDoneSentinel()
    {
        var client = ClientWith(new SseHandler(
            "data: {\"sent\":1}\n\n",
            "data: [DONE]\n\n",
            "data: {\"sent\":999}\n\n"));

        var seen = new List<string>();
        await foreach (var e in client.Streaming_CampaignSendAsync("camp1"))
            seen.Add(e.Raw);

        // Anything after the sentinel must never be delivered.
        Assert.Single(seen);
        Assert.Equal("{\"sent\":1}", seen[0]);
    }

    [Fact]
    public async Task Stream_UsesTheUnversionedApiBase()
    {
        string? seenUri = null;
        var client = new MisarMailClient(
            apiKey: "test-key",
            httpClient: new HttpClient(new UriCapturingHandler(u => seenUri = u)));

        await foreach (var _ in client.Streaming_CampaignSendAsync("camp1")) { }

        // Both SSE routes live outside /v1, so the path must not carry it.
        Assert.NotNull(seenUri);
        Assert.Equal("https://api.misar.io/mail/campaigns/camp1/send-stream", seenUri);
    }

    private sealed class UriCapturingHandler : HttpMessageHandler
    {
        private readonly Action<string> _capture;
        public UriCapturingHandler(Action<string> capture) => _capture = capture;

        protected override Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request, CancellationToken cancellationToken)
        {
            _capture(request.RequestUri!.ToString());
            return Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent("data: [DONE]\n\n", Encoding.UTF8, "text/event-stream")
            });
        }
    }

    [Fact]
    public async Task StreamRefusal_ThrowsPlanLimitBeforeAnyFrame()
    {
        const string body = """
        {"code":"plan_limit_exceeded","error":"streaming is not on your plan",
         "upgrade":{"feature":"campaign_streaming","urls":{"pricing":"https://misarmail.com/pricing"}}}
        """;
        var client = ClientWith(new SseHandler(402, body, ("X-Misar-Plan", "free")));

        var ex = await Assert.ThrowsAsync<MisarMailPlanLimitException>(async () =>
        {
            await foreach (var _ in client.Streaming_CampaignSendAsync("locked"))
                Assert.Fail("no frame should be delivered on a refusal");
        });

        Assert.Equal(402, ex.Status);
        Assert.Equal("free", ex.Plan);
        Assert.Equal("campaign_streaming", ex.Feature);
    }

    [Fact]
    public async Task Stream_NonJsonPayloadStillArrivesAsRaw()
    {
        var client = ClientWith(new SseHandler("data: not json\n\n", "data: [DONE]\n\n"));

        var seen = new List<MisarMailStreamEvent>();
        await foreach (var e in client.Streaming_CampaignSendAsync("camp1"))
            seen.Add(e);

        Assert.Single(seen);
        Assert.Null(seen[0].Data);
        Assert.Equal("not json", seen[0].Raw);
    }
}
