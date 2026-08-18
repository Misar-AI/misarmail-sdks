<?php

declare(strict_types=1);

namespace MisarMail;

/**
 * monetization — generated.
 */
class MonetizationResource
{
    public function __construct(private readonly Client $client) {}

    /**
     * POST /monetization/tip
     *
     * @return array<string,mixed>
     */
    public function tip(array $data = []): array
    {
        return $this->client->request('POST', '/monetization/tip', $data);
    }

}
