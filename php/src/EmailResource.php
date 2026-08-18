<?php

declare(strict_types=1);

namespace MisarMail;

// ── Resource: Email ───────────────────────────────────────────────────────────

class EmailResource
{
    public function __construct(private readonly Client $client) {}

    public function send(array $data): array
    {
        return $this->client->request('POST', '/send', $data);
    }
}
