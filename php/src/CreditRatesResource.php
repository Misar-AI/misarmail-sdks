<?php

declare(strict_types=1);

namespace MisarMail;

/**
 * creditRates — generated.
 */
class CreditRatesResource
{
    public function __construct(private readonly Client $client) {}

    /**
     * GET /credit-rates
     *
     * @return array<string,mixed>
     */
    public function list(): array
    {
        return $this->client->request('GET', '/credit-rates');
    }

}
