<?php

declare(strict_types=1);

namespace MisarMail;

// ── Resource: Track ───────────────────────────────────────────────────────────

class TrackResource
{
    public function __construct(private readonly Client $client) {}

    public function event(array $data): array
    {
        return $this->client->request('POST', '/track/event', $data);
    }

    public function purchase(array $data): array
    {
        return $this->client->request('POST', '/track/purchase', $data);
    }
}
