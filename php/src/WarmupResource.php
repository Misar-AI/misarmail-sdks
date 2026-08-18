<?php

declare(strict_types=1);

namespace MisarMail;

/**
 * warmup — generated.
 */
class WarmupResource
{
    public function __construct(private readonly Client $client) {}

    /**
     * GET /warmup
     *
     * @return array<string,mixed>
     */
    public function get(): array
    {
        return $this->client->request('GET', '/warmup');
    }
}
