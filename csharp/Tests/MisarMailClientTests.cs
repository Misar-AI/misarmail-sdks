using System.Net;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using Misar.Mail;
using Xunit;

namespace Misar.Mail.Tests;

/// <summary>
/// Unit tests for <see cref="MisarMailClient"/>.
///
/// A <see cref="StubHttpMessageHandler"/> replaces the real <see cref="HttpClient"/>
/// transport so no network calls are made.
/// </summary>
public sealed class MisarMailClientTests
{
    // -------------------------------------------------------------------------
    // Stub handler
    // -------------------------------------------------------------------------

    private sealed class StubHttpMessageHandler : HttpMessageHandler
    {
        private readonly int _statusCode;
        private readonly string _body;

        public StubHttpMessageHandler(int statusCode, string body)
        {
            _statusCode = statusCode;
            _body = body;
        }

        protected override Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request,
            CancellationToken cancellationToken)
        {
            var response = new HttpResponseMessage((HttpStatusCode)_statusCode)
            {
                Content = new StringContent(_body, Encoding.UTF8, "application/json")
            };
            return Task.FromResult(response);
        }
    }

    private static MisarMailClient ClientWith(int status, string body)
    {
        var handler = new StubHttpMessageHandler(status, body);
        var httpClient = new HttpClient(handler);
        return new MisarMailClient(
            apiKey: "your_api_key_here",
            maxRetries: 1,        // single attempt — no real back-off in unit tests
            httpClient: httpClient);
    }

    // -------------------------------------------------------------------------
    // Tests
    // -------------------------------------------------------------------------

    [Fact]
    public async Task SendEmail_200_ReturnsParsedResponse()
    {
        using var client = ClientWith(200, """{"id":"msg_1","status":"queued"}""");
        var result = await client.SendEmailAsync(new { to = "a@b.com", subject = "Hi" });
        Assert.Equal("msg_1", result.GetProperty("id").GetString());
        Assert.Equal("queued", result.GetProperty("status").GetString());
    }

    [Fact]
    public async Task ContactsList_200_ReturnsParsedResponse()
    {
        using var client = ClientWith(200, """{"data":[]}""");
        var result = await client.ContactsListAsync();
        Assert.True(result.TryGetProperty("data", out _));
    }

    [Fact]
    public async Task ContactsCreate_201_ReturnsParsedResponse()
    {
        using var client = ClientWith(201, """{"id":"c1","email":"x@y.com"}""");
        var result = await client.ContactsCreateAsync(new { email = "x@y.com" });
        Assert.Equal("c1", result.GetProperty("id").GetString());
    }

    [Fact]
    public async Task AnalyticsGet_200_ReturnsParsedResponse()
    {
        using var client = ClientWith(200, """{"opens":10,"clicks":3}""");
        var result = await client.AnalyticsGetAsync("camp_abc");
        Assert.Equal(10, result.GetProperty("opens").GetInt32());
    }

    [Fact]
    public async Task ValidateEmail_200_ReturnsParsedResponse()
    {
        using var client = ClientWith(200, """{"valid":true}""");
        var result = await client.ValidateEmailAsync("test@example.com");
        Assert.True(result.GetProperty("valid").GetBoolean());
    }

    [Fact]
    public async Task TemplatesRender_200_ReturnsParsedResponse()
    {
        using var client = ClientWith(200, """{"html":"<p>Hello</p>"}""");
        var result = await client.TemplatesRenderAsync("tmpl_1", new { name = "World" });
        Assert.Equal("<p>Hello</p>", result.GetProperty("html").GetString());
    }

    [Fact]
    public async Task Non2xx_ThrowsMisarMailException_WithCorrectStatus()
    {
        using var client = ClientWith(401, """{"error":"Unauthorized"}""");
        var ex = await Assert.ThrowsAsync<MisarMailException>(
            () => client.SendEmailAsync(new { to = "x@y.com" }));
        Assert.Equal(401, ex.Status);
    }

    [Fact]
    public async Task Status404_ThrowsMisarMailException()
    {
        using var client = ClientWith(404, """{"error":"not found"}""");
        var ex = await Assert.ThrowsAsync<MisarMailException>(
            () => client.AnalyticsGetAsync("nonexistent"));
        Assert.Equal(404, ex.Status);
    }

    [Fact]
    public async Task EmptyBody_200_ReturnsEmptyJsonObject()
    {
        using var client = ClientWith(200, "");
        var result = await client.SandboxListAsync();
        Assert.Equal(JsonValueKind.Object, result.ValueKind);
    }

    [Fact]
    public async Task TrackEvent_200_ReturnsParsedResponse()
    {
        using var client = ClientWith(200, """{"tracked":true}""");
        var result = await client.TrackEventAsync(new { @event = "signup" });
        Assert.True(result.GetProperty("tracked").GetBoolean());
    }

    [Fact]
    public async Task TrackPurchase_200_ReturnsParsedResponse()
    {
        using var client = ClientWith(200, """{"tracked":true}""");
        var result = await client.TrackPurchaseAsync(new { email = "u@x.com", amount = 99.0 });
        Assert.True(result.GetProperty("tracked").GetBoolean());
    }

    [Fact]
    public void Constructor_BlankApiKey_ThrowsArgumentException()
    {
        Assert.Throws<ArgumentException>(() => new MisarMailClient(""));
    }
}
