<?php

declare(strict_types=1);

namespace MisarMail;

/**
 * deliverability — generated.
 */
class DeliverabilityResource
{
    public function __construct(private readonly Client $client) {}

    /**
     * GET /deliverability/audit
     *
     * @return array<string,mixed>
     */
    public function audit(): array
    {
        return $this->client->request('GET', '/deliverability/audit');
    }

    /**
     * GET /deliverability/score
     *
     * @return array<string,mixed>
     */
    public function score(): array
    {
        return $this->client->request('GET', '/deliverability/score');
    }

}
