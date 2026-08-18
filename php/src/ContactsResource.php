<?php

declare(strict_types=1);

namespace MisarMail;

// ── Resource: Contacts ────────────────────────────────────────────────────────

class ContactsResource
{
    public function __construct(private readonly Client $client) {}

    public function list(int $page = 1, int $limit = 20): array
    {
        return $this->client->request('GET', '/contacts?' . http_build_query(['page' => $page, 'limit' => $limit]));
    }

    public function create(array $data): array
    {
        return $this->client->request('POST', '/contacts', $data);
    }

    public function get(string $id): array
    {
        return $this->client->request('GET', '/contacts?id=' . rawurlencode($id));
    }

    public function update(string $email, array $data): array
    {
        return $this->client->request('PATCH', '/contacts', $data + ['email' => $email]);
    }

    public function delete(string $id): array
    {
        return $this->client->request('DELETE', '/contacts?id=' . rawurlencode($id));
    }

    public function import(array $data): array
    {
        return $this->client->request('POST', '/contacts/import', $data);
    }
}
