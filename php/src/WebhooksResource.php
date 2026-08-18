<?php

declare(strict_types=1);

namespace MisarMail;

// ── Resource: Webhooks ────────────────────────────────────────────────────────

class WebhooksResource
{
    public function __construct(private readonly Client $client) {}

    public function list(): array
    {
        return $this->client->request('GET', '/webhooks');
    }

    public function create(array $data): array
    {
        return $this->client->request('POST', '/webhooks', $data);
    }

    public function get(string $id): array
    {
        return $this->client->request('GET', "/webhooks/{$id}");
    }

    public function update(string $id, array $data): array
    {
        return $this->client->request('PATCH', "/webhooks/{$id}", $data);
    }

    public function delete(string $id): array
    {
        return $this->client->request('DELETE', "/webhooks/{$id}");
    }

    public function test(string $id): array
    {
        return $this->client->request('POST', "/webhooks/{$id}/test");
    }
}
