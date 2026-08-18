<?php

declare(strict_types=1);

namespace MisarMail;

// ── Resource: Validate ────────────────────────────────────────────────────────

class ValidateResource
{
    public function __construct(private readonly Client $client) {}

    public function email(string $address): array
    {
        return $this->client->request('POST', '/validate', ['email' => $address]);
    }
}
