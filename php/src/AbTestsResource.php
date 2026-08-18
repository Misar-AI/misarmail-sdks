<?php

declare(strict_types=1);

namespace MisarMail;

// ── Resource: A/B Tests ───────────────────────────────────────────────────────

class AbTestsResource
{
    public function __construct(private readonly Client $client) {}

    public function list(): array
    {
        return $this->client->request('GET', '/ab-tests');
    }

    public function create(array $data): array
    {
        return $this->client->request('POST', '/ab-tests', $data);
    }

    public function get(string $id): array
    {
        return $this->client->request('GET', "/ab-tests/{$id}");
    }

    public function setWinner(string $id, string $variantId): array
    {
        return $this->client->request('POST', "/ab-tests/{$id}/winner", ['variant_id' => $variantId]);
    }
}
