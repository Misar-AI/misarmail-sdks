<?php

declare(strict_types=1);

namespace MisarMail;

/**
 * revenue — generated.
 */
class RevenueResource
{
    public function __construct(private readonly Client $client) {}

    /**
     * GET /revenue/attribution
     *
     * @return array<string,mixed>
     */
    public function attribution(?string $campaign_id = null, ?string $period = null): array
    {
        $q = array_filter([
            'campaign_id' => $campaign_id,
            'period' => $period,
        ], static fn ($v) => $v !== null);
        return $this->client->request('GET', '/revenue/attribution' . ($q === [] ? '' : '?' . http_build_query($q)));
    }

}
