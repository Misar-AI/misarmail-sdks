using System.Net.Http.Headers;
using System.Runtime.CompilerServices;
using System.Text;
using System.Text.Json;

namespace MisarMail;

/// <summary>
/// One decoded Server-Sent Events frame.
///
/// MisarMail emits unnamed frames — <c>data: {...}</c> with no <c>event:</c>
/// line — so <see cref="Event"/> is normally null. <see cref="Data"/> is the
/// decoded JSON, or null when the payload was not JSON; <see cref="Raw"/> is
/// always the payload exactly as received.
/// </summary>
public sealed record MisarMailStreamEvent(string? Event, JsonElement? Data, string Raw);

public sealed partial class MisarMailClient
{
    /// <summary>
    /// <c>POST /api/ai/generate-email/stream</c> — token-by-token generation.
    /// </summary>
    /// <example>
    /// <code>
    /// await foreach (var e in client.Streaming_GenerateEmailAsync(new { prompt = "…" }))
    ///     Console.Write(e.Data?.GetProperty("delta").GetString());
    /// </code>
    /// </example>
    public IAsyncEnumerable<MisarMailStreamEvent> Streaming_GenerateEmailAsync(
        object options, CancellationToken ct = default) =>
        SseStreamAsync(HttpMethod.Post, "/ai/generate-email/stream", options, ct);

    /// <summary>
    /// <c>GET /api/campaigns/{id}/send-stream</c> — live send progress.
    /// </summary>
    public IAsyncEnumerable<MisarMailStreamEvent> Streaming_CampaignSendAsync(
        string campaignId, CancellationToken ct = default) =>
        SseStreamAsync(
            HttpMethod.Get,
            $"/campaigns/{Uri.EscapeDataString(campaignId)}/send-stream",
            null,
            ct);

    /// <summary>
    /// Opens an SSE connection and yields each frame as it arrives.
    ///
    /// Uses the API base, since both streaming routes sit outside <c>/v1</c>.
    /// Frames end at a blank line and may span several <c>data:</c> lines; the
    /// <c>[DONE]</c> sentinel ends the stream and is not yielded.
    ///
    /// Deliberately not retried: replaying a stream that failed mid-flight
    /// would duplicate whatever the caller already consumed.
    /// </summary>
    private async IAsyncEnumerable<MisarMailStreamEvent> SseStreamAsync(
        HttpMethod method,
        string path,
        object? body,
        [EnumeratorCancellation] CancellationToken ct = default)
    {
        using var request = new HttpRequestMessage(method, _apiBase + path);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _apiKey);
        request.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue("text/event-stream"));
        if (body is not null)
            request.Content = new StringContent(
                JsonSerializer.Serialize(body), Encoding.UTF8, "application/json");

        HttpResponseMessage response;
        try
        {
            // ResponseHeadersRead is what makes this a stream rather than a
            // buffered read of the whole body.
            response = await _httpClient
                .SendAsync(request, HttpCompletionOption.ResponseHeadersRead, ct)
                .ConfigureAwait(false);
        }
        catch (Exception ex) when (ex is HttpRequestException or TaskCanceledException)
        {
            throw new MisarMailNetworkException(ex.Message);
        }

        using (response)
        {
            int status = (int)response.StatusCode;

            if (!response.IsSuccessStatusCode)
            {
                string raw = await response.Content.ReadAsStringAsync(ct).ConfigureAwait(false);
                if (IsPlanLimit(raw))
                    throw BuildPlanLimitError(status, raw, response);
                throw new MisarMailException(status, ExtractError(raw));
            }

            await using var stream = await response.Content
                .ReadAsStreamAsync(ct).ConfigureAwait(false);
            using var reader = new StreamReader(stream, Encoding.UTF8);

            string? eventName = null;
            var dataLines = new List<string>();

            while (true)
            {
                string? line;
                try
                {
                    line = await reader.ReadLineAsync(ct).ConfigureAwait(false);
                }
                catch (Exception ex) when (ex is IOException or HttpRequestException)
                {
                    throw new MisarMailNetworkException($"stream read: {ex.Message}");
                }
                if (line is null) break;

                if (line.Length == 0)
                {
                    var frame = BuildFrame(ref eventName, dataLines);
                    if (frame is null) continue;              // keepalive or empty
                    if (ReferenceEquals(frame, DoneFrame)) yield break;
                    yield return frame;
                    continue;
                }
                // Comments are keepalives.
                if (line[0] == ':') continue;

                if (line.StartsWith("event:", StringComparison.Ordinal))
                    eventName = line[6..].Trim();
                else if (line.StartsWith("data:", StringComparison.Ordinal))
                    dataLines.Add(line[5..].StartsWith(' ') ? line[6..] : line[5..]);
            }

            // A final frame with no trailing blank line.
            var tail = BuildFrame(ref eventName, dataLines);
            if (tail is not null && !ReferenceEquals(tail, DoneFrame))
                yield return tail;
        }
    }

    /// <summary>Sentinel identity for <c>data: [DONE]</c>, compared by reference.</summary>
    private static readonly MisarMailStreamEvent DoneFrame = new(null, null, "[DONE]");

    /// <summary>
    /// Consumes the accumulated lines into one frame, clearing them either way.
    /// Returns <see cref="DoneFrame"/> for the sentinel and null for an empty frame.
    /// </summary>
    private static MisarMailStreamEvent? BuildFrame(ref string? eventName, List<string> dataLines)
    {
        if (dataLines.Count == 0)
        {
            eventName = null;
            return null;
        }
        string raw = string.Join("\n", dataLines);
        string? name = eventName;
        dataLines.Clear();
        eventName = null;

        if (raw == "[DONE]") return DoneFrame;

        JsonElement? data = null;
        try
        {
            using var doc = JsonDocument.Parse(raw);
            data = doc.RootElement.Clone();
        }
        catch (JsonException) { /* not JSON — Raw still carries it */ }

        return new MisarMailStreamEvent(name, data, raw);
    }
}
