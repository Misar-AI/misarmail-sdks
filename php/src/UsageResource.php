<?php

declare(strict_types=1);

namespace MisarMail;

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
