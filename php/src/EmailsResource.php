<?php

declare(strict_types=1);

namespace MisarMail;

/**
 * emails — generated.
 */
class EmailsResource
{
    public function __construct(private readonly Client $client) {}

    /**
     * GET /emails
     *
     * @return array<string,mixed>
     */
    public function list(?string $folder = null, ?string $search = null, ?int $limit = null): array
    {
        $q = array_filter([
            'folder' => $folder,
            'search' => $search,
            'limit' => $limit,
        ], static fn ($v) => $v !== null);
        return $this->client->request('GET', '/emails' . ($q === [] ? '' : '?' . http_build_query($q)));
    }

    /**
     * GET /emails/:id
     *
     * @return array<string,mixed>
     */
    public function get(string $id): array
    {
        return $this->client->request('GET', '/emails/' . rawurlencode($id));
    }

    /**
     * PATCH /emails/:id
     *
     * @return array<string,mixed>
     */
    public function update(string $id, array $data = []): array
    {
        return $this->client->request('PATCH', '/emails/' . rawurlencode($id), $data);
    }

}
