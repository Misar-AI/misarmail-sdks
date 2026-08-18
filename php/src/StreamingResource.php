<?php

declare(strict_types=1);

namespace MisarMail;

/**
 * The two Server-Sent Events endpoints.
 *
 * Both live outside /v1 and are API-key authenticated like everything else, so
 * a plan refusal surfaces as PlanLimitError here too.
 */
class StreamingResource
{
    public function __construct(private readonly Client $client) {}

    /**
     * POST /api/ai/generate-email/stream — token-by-token generation.
     *
     * @param array<string,mixed>            $options
     * @param callable(StreamEvent): (bool|void) $onEvent Returning false stops the stream.
     */
    public function generateEmail(array $options, callable $onEvent): void
    {
        $this->client->sseStream('POST', '/ai/generate-email/stream', $options, $onEvent);
    }

    /**
     * GET /api/campaigns/{id}/send-stream — live send progress.
     *
     * @param callable(StreamEvent): (bool|void) $onEvent
     */
    public function campaignSend(string $campaignId, callable $onEvent): void
    {
        $this->client->sseStream(
            'GET',
            '/campaigns/' . rawurlencode($campaignId) . '/send-stream',
            null,
            $onEvent,
        );
    }
}
