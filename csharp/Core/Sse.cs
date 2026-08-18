using System;
using System.Collections.Generic;
using System.IO;
using System.Net.Http;
using System.Runtime.CompilerServices;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;

namespace Misar.Mail.Core;

/// <summary>
/// Server-Sent Events client for the MisarMail streaming endpoints.
/// </summary>
/// <remarks>
/// Both streams frame events as <c>data: &lt;json&gt;</c> and close with the
/// sentinel <c>data: [DONE]</c>. One of the two is a POST, so the stream reads
/// the response body incrementally rather than using an EventSource-style
/// helper.
/// </remarks>
public static class Sse
{
    private const string Done = "[DONE]";

    /// <summary>Yields one decoded payload per SSE event.</summary>
    public static async IAsyncEnumerable<JsonElement> StreamAsync(
        string url,
        string apiKey,
        HttpMethod method,
        object? body,
        [EnumeratorCancellation] CancellationToken cancellationToken = default)
    {
        // A stream has no useful deadline, so it gets its own client rather
        // than inheriting the transport's per-request timeout.
        using var http = new HttpClient { Timeout = Timeout.InfiniteTimeSpan };
        using var request = new HttpRequestMessage(method, url);

        request.Headers.TryAddWithoutValidation("Authorization", "Bearer " + apiKey);
        request.Headers.TryAddWithoutValidation("Accept", "text/event-stream");

        if (body is not null)
        {
            request.Content = new StringContent(
                JsonSerializer.Serialize(body), Encoding.UTF8, "application/json");
        }

        using var response = await http
            .SendAsync(request, HttpCompletionOption.ResponseHeadersRead, cancellationToken)
            .ConfigureAwait(false);

        if ((int)response.StatusCode >= 400)
        {
            // Errors arrive as a normal JSON body, not as an SSE frame.
            var raw = await response.Content.ReadAsStringAsync(cancellationToken).ConfigureAwait(false);
            Transport.Decode((int)response.StatusCode, raw);
        }

        await using var stream = await response.Content
            .ReadAsStreamAsync(cancellationToken).ConfigureAwait(false);
        using var reader = new StreamReader(stream, Encoding.UTF8);

        while (!reader.EndOfStream)
        {
            cancellationToken.ThrowIfCancellationRequested();

            var line = await reader.ReadLineAsync(cancellationToken).ConfigureAwait(false);
            if (line is null || !line.StartsWith("data:", StringComparison.Ordinal))
            {
                continue;
            }

            var payload = line[5..].Trim();
            if (payload == Done)
            {
                yield break;
            }
            if (payload.Length == 0)
            {
                continue;
            }

            JsonElement element;
            try
            {
                element = JsonDocument.Parse(payload).RootElement.Clone();
            }
            catch (JsonException)
            {
                // One malformed frame should not discard everything already
                // streamed.
                element = JsonDocument.Parse($"{{\"raw\":{JsonSerializer.Serialize(payload)}}}")
                    .RootElement.Clone();
            }

            yield return element;
        }
    }
}
