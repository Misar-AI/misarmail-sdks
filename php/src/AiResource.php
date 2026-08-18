<?php

declare(strict_types=1);

namespace MisarMail;

// ── Generated from scripts/sdk-endpoint-spec.json ────────────────────────────
//
// These twenty endpoints were missing from every SDK except TypeScript.

/**
 * ai — generated.
 */
class AiResource
{
    public function __construct(private readonly Client $client) {}

    /**
     * POST /ai/subject-lines
     *
     * @return array<string,mixed>
     */
    public function subjectLines(array $data = []): array
    {
        return $this->client->request('POST', '/ai/subject-lines', $data);
    }

}
