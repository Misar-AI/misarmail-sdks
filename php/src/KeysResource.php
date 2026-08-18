<?php

declare(strict_types=1);

namespace MisarMail;

// ── Resource: API Keys ────────────────────────────────────────────────────────

class KeysResource
{
    public function __construct(private readonly Client $client) {}

    public function list(): array
    {
        return $this->client->request('GET', '/keys');
    }

    public function create(array $data): array
    {
        return $this->client->request('POST', '/keys', $data);
    }

    public function get(string $id): array
    {
        return $this->client->request('GET', "/keys/{$id}");
    }

    public function revoke(string $id): array
    {
        return $this->client->request('DELETE', "/keys/{$id}");
    }
}
