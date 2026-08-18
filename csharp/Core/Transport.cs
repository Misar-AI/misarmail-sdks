using System;
using System.Net.Http;
using System.Net.Http.Json;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;

namespace Misar.Mail.Core;

/// <summary>
/// HTTP transport shared by the generated resource layer.
/// </summary>
/// <remarks>
/// Everything the SDK does goes through one of three transports — HTTP for
/// REST, SSE for streaming, WebSocket for push — and all three authenticate the
/// same way: the account API key, sent as a bearer token. There is no second
/// credential path. What a key may do, and how much of it, is decided
/// server-side from the subscription behind that key.
/// </remarks>
public sealed class Transport : IDisposable
{
    private static readonly int[] RetryableStatuses = { 429, 500, 502, 503, 504 };

    private readonly HttpClient _http;
    private readonly bool _ownsClient;
    private readonly int _maxRetries;

    public Transport(
        string apiKey,
        string baseUrl = "https://api.misar.io/mail",
        int maxRetries = 3,
        TimeSpan? timeout = null,
        HttpClient? httpClient = null)
    {
        if (string.IsNullOrEmpty(apiKey))
        {
            throw new ArgumentException(
                "A MisarMail API key is required. Create one at https://mail.misar.io/settings/api-keys.",
                nameof(apiKey));
        }

        ApiKey = apiKey;
        BaseUrl = baseUrl.TrimEnd('/');
        _maxRetries = maxRetries;
        _ownsClient = httpClient is null;
        _http = httpClient ?? new HttpClient { Timeout = timeout ?? TimeSpan.FromSeconds(30) };
    }

    public string ApiKey { get; }

    public string BaseUrl { get; }

    /// <summary>Issues a request against a manifest path and decodes the JSON body.</summary>
    public async Task<JsonElement> RequestAsync(
        string method,
        string path,
        object? body,
        CancellationToken cancellationToken = default)
    {
        var url = BaseUrl + path;

        for (var attempt = 0; ; attempt++)
        {
            HttpResponseMessage response;

            try
            {
                using var request = new HttpRequestMessage(new HttpMethod(method), url);
                request.Headers.TryAddWithoutValidation("Authorization", "Bearer " + ApiKey);

                if (body is not null)
                {
                    request.Content = new StringContent(
                        JsonSerializer.Serialize(body), Encoding.UTF8, "application/json");
                }

                response = await _http.SendAsync(request, cancellationToken).ConfigureAwait(false);
            }
            catch (Exception ex) when (ex is not OperationCanceledException)
            {
                if (attempt < _maxRetries - 1)
                {
                    await Task.Delay(Backoff(attempt, null), cancellationToken).ConfigureAwait(false);
                    continue;
                }
                throw new MisarMailException(0, ex.Message, "network_error");
            }

            using (response)
            {
                var status = (int)response.StatusCode;

                if (Array.IndexOf(RetryableStatuses, status) >= 0 && attempt < _maxRetries - 1)
                {
                    await Task.Delay(Backoff(attempt, response), cancellationToken).ConfigureAwait(false);
                    continue;
                }

                var raw = await response.Content.ReadAsStringAsync(cancellationToken).ConfigureAwait(false);
                return Decode(status, raw);
            }
        }
    }

    internal static JsonElement Decode(int status, string raw)
    {
        JsonElement data = default;
        var parsed = false;

        if (!string.IsNullOrEmpty(raw))
        {
            try
            {
                data = JsonDocument.Parse(raw).RootElement.Clone();
                parsed = true;
            }
            catch (JsonException)
            {
                // A non-JSON error body is still an error; the status carries
                // the meaning.
            }
        }

        if (status >= 400)
        {
            var message = "HTTP " + status;
            var errorType = "api_error";

            if (parsed && data.ValueKind == JsonValueKind.Object)
            {
                if (data.TryGetProperty("error", out var error) && error.ValueKind == JsonValueKind.String)
                {
                    message = error.GetString() ?? message;
                }
                else if (data.TryGetProperty("message", out var m) && m.ValueKind == JsonValueKind.String)
                {
                    message = m.GetString() ?? message;
                }

                if (data.TryGetProperty("error_type", out var t) && t.ValueKind == JsonValueKind.String)
                {
                    errorType = t.GetString() ?? errorType;
                }
            }

            throw new MisarMailException(status, message, errorType);
        }

        return data;
    }

    /// <summary>
    /// Exponential backoff, but honours Retry-After when the server sends one:
    /// on a 429 the server knows when the window reopens, and guessing wastes
    /// the caller's remaining budget.
    /// </summary>
    private static TimeSpan Backoff(int attempt, HttpResponseMessage? response)
    {
        var retryAfter = response?.Headers.RetryAfter?.Delta;
        if (retryAfter is { } delta && delta > TimeSpan.Zero)
        {
            return delta > TimeSpan.FromMinutes(1) ? TimeSpan.FromMinutes(1) : delta;
        }

        return TimeSpan.FromMilliseconds(200 * Math.Pow(2, attempt));
    }

    public void Dispose()
    {
        if (_ownsClient)
        {
            _http.Dispose();
        }
    }
}
