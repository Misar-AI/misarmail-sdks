<?php

declare(strict_types=1);

namespace MisarMail;

// ── Resource: Domains ─────────────────────────────────────────────────────────

class DomainsResource
{
    public function __construct(private readonly Client $client) {}

    public function list(): array
    {
        return $this->client->request('GET', '/domains', [], $this->client->apiBase);
    }

    public function create(array $data): array
    {
        return $this->client->request('POST', '/domains', $data, $this->client->apiBase);
    }

    public function get(string $id): array
    {
        return $this->client->request('GET', "/domains/{$id}", [], $this->client->apiBase);
    }

    public function verify(string $id): array
    {
        return $this->client->request('POST', "/domains/{$id}/verify", [], $this->client->apiBase);
    }

    public function delete(string $id): array
    {
        return $this->client->request('DELETE', "/domains/{$id}", [], $this->client->apiBase);
    }
}
