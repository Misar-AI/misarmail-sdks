<?php

declare(strict_types=1);

namespace MisarMail;

/**
 * subscription — generated.
 */
class SubscriptionResource
{
    public function __construct(private readonly Client $client) {}

    /**
     * GET /subscription
     *
     * @return array<string,mixed>
     */
    public function get(?string $product = null): array
    {
        $q = array_filter([
            'product' => $product,
        ], static fn ($v) => $v !== null);
        return $this->client->request('GET', '/subscription' . ($q === [] ? '' : '?' . http_build_query($q)));
    }

    /**
     * POST /subscription
     *
     * @return array<string,mixed>
     */
    public function upsert(array $data = []): array
    {
        return $this->client->request('POST', '/subscription', $data);
    }

    /**
     * DELETE /subscription
     *
     * @return array<string,mixed>
     */
    public function cancel(array $data = []): array
    {
        return $this->client->request('DELETE', '/subscription', $data);
    }

}
