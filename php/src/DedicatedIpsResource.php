<?php

declare(strict_types=1);

namespace MisarMail;

// ── Resource: Dedicated IPs ───────────────────────────────────────────────────

class DedicatedIpsResource
{
    public function __construct(private readonly Client $client) {}

    public function list(): array
    {
        return $this->client->request('GET', '/dedicated-ips');
    }

    public function create(array $data): array
    {
        return $this->client->request('POST', '/dedicated-ips', $data);
    }

    public function update(string $id, array $data): array
    {
        return $this->client->request('PATCH', "/dedicated-ips/{$id}", $data);
    }

    public function delete(string $id): array
    {
        return $this->client->request('DELETE', "/dedicated-ips/{$id}");
    }
}
