<?php

declare(strict_types=1);

namespace MisarMail;

// ── Resource: Templates ───────────────────────────────────────────────────────

class TemplatesResource
{
    public function __construct(private readonly Client $client) {}

    public function list(): array
    {
        return $this->client->request('GET', '/templates');
    }

    public function create(array $data): array
    {
        return $this->client->request('POST', '/templates', $data);
    }

    public function get(string $id): array
    {
        return $this->client->request('GET', "/templates/{$id}");
    }

    public function update(string $id, array $data): array
    {
        return $this->client->request('PATCH', "/templates/{$id}", $data);
    }

    public function delete(string $id): array
    {
        return $this->client->request('DELETE', "/templates/{$id}");
    }

    public function render(array $data): array
    {
        return $this->client->request('POST', '/templates/render', $data);
    }
}
