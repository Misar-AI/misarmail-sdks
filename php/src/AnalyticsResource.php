<?php

declare(strict_types=1);

namespace MisarMail;

// ── Resource: Analytics ───────────────────────────────────────────────────────

class AnalyticsResource
{
    public function __construct(private readonly Client $client) {}

    public function overview(array $params = []): array
    {
        $qs = $params ? '?' . http_build_query($params) : '';
        return $this->client->request('GET', "/analytics{$qs}");
    }
}
