<?php

declare(strict_types=1);

namespace MisarMail;

// ── Resource: Inbound ─────────────────────────────────────────────────────────

class InboundResource
{
    public function __construct(private readonly Client $client) {}

    public function list(array $params = []): array
    {
        $qs = $params ? '?' . http_build_query($params) : '';
        return $this->client->request('GET', "/inbound{$qs}");
    }

    public function create(array $data): array
    {
        return $this->client->request('POST', '/inbound', $data);
    }

    public function get(string $id): array
    {
        return $this->client->request('GET', "/inbound/{$id}");
    }

    public function delete(string $id): array
    {
        return $this->client->request('DELETE', "/inbound/{$id}");
    }
}
