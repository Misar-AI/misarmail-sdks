<?php

declare(strict_types=1);

namespace MisarMail;

// ── Resource: Automations ─────────────────────────────────────────────────────

class AutomationsResource
{
    public function __construct(private readonly Client $client) {}

    public function list(array $params = []): array
    {
        $qs = $params ? '?' . http_build_query($params) : '';
        return $this->client->request('GET', "/automations{$qs}");
    }

    public function create(array $data): array
    {
        return $this->client->request('POST', '/automations', $data);
    }

    public function get(string $id): array
    {
        return $this->client->request('GET', "/automations/{$id}");
    }

    public function update(string $id, array $data): array
    {
        return $this->client->request('PATCH', "/automations/{$id}", $data);
    }

    public function delete(string $id): array
    {
        return $this->client->request('DELETE', "/automations/{$id}");
    }

    public function activate(string $id, bool $active): array
    {
        return $this->client->request('POST', "/automations/{$id}/activate", ['active' => $active]);
    }
}
