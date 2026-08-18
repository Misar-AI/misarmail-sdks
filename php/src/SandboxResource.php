<?php

declare(strict_types=1);

namespace MisarMail;

// ── Resource: Sandbox ─────────────────────────────────────────────────────────

class SandboxResource
{
    public function __construct(private readonly Client $client) {}

    public function send(array $data): array
    {
        return $this->client->request('POST', '/sandbox/send', $data);
    }

    public function list(array $params = []): array
    {
        $qs = $params ? '?' . http_build_query($params) : '';
        return $this->client->request('GET', "/sandbox{$qs}");
    }

    public function delete(string $id): array
    {
        return $this->client->request('DELETE', "/sandbox/{$id}");
    }
}
