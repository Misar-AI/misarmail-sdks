<?php

declare(strict_types=1);

namespace MisarMail;

/**
 * landingPages — generated.
 */
class LandingPagesResource
{
    public function __construct(private readonly Client $client) {}

    /**
     * POST /landing-pages
     *
     * @return array<string,mixed>
     */
    public function create(array $data = []): array
    {
        return $this->client->request('POST', '/landing-pages', $data);
    }

}
