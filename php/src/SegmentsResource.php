<?php

declare(strict_types=1);

namespace MisarMail;

/**
 * segments — generated.
 */
class SegmentsResource
{
    public function __construct(private readonly Client $client) {}

    /**
     * GET /segments/:id/members
     *
     * @return array<string,mixed>
     */
    public function members(string $id, ?int $page = null, ?int $limit = null): array
    {
        $q = array_filter([
            'page' => $page,
            'limit' => $limit,
        ], static fn ($v) => $v !== null);
        return $this->client->request('GET', '/segments/' . rawurlencode($id) . '/members' . ($q === [] ? '' : '?' . http_build_query($q)));
    }

}
