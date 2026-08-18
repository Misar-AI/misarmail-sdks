<?php

declare(strict_types=1);

namespace MisarMail;

/**
 * dmarc — generated.
 */
class DmarcResource
{
    public function __construct(private readonly Client $client) {}

    /**
     * GET /dmarc/check
     *
     * @return array<string,mixed>
     */
    public function check(?string $domain = null, ?string $dkim_selector = null): array
    {
        $q = array_filter([
            'domain' => $domain,
            'dkim_selector' => $dkim_selector,
        ], static fn ($v) => $v !== null);
        return $this->client->request('GET', '/dmarc/check' . ($q === [] ? '' : '?' . http_build_query($q)));
    }

    /**
     * GET /dmarc/domains
     *
     * @return array<string,mixed>
     */
    public function listDomains(): array
    {
        return $this->client->request('GET', '/dmarc/domains');
    }

    /**
     * POST /dmarc/domains
     *
     * @return array<string,mixed>
     */
    public function addDomain(array $data = []): array
    {
        return $this->client->request('POST', '/dmarc/domains', $data);
    }

    /**
     * DELETE /dmarc/domains
     *
     * @return array<string,mixed>
     */
    public function removeDomain(?string $domain_id = null): array
    {
        $q = array_filter([
            'domain_id' => $domain_id,
        ], static fn ($v) => $v !== null);
        return $this->client->request('DELETE', '/dmarc/domains' . ($q === [] ? '' : '?' . http_build_query($q)));
    }

}
