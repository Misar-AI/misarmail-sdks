<?php

declare(strict_types=1);

namespace MisarMail;

/**
 * wallet — generated.
 */
class WalletResource
{
    public function __construct(private readonly Client $client) {}

    /**
     * GET /wallet
     *
     * @return array<string,mixed>
     */
    public function get(): array
    {
        return $this->client->request('GET', '/wallet');
    }

    /**
     * POST /wallet/credit
     *
     * @return array<string,mixed>
     */
    public function credit(array $data = []): array
    {
        return $this->client->request('POST', '/wallet/credit', $data);
    }

    /**
     * POST /wallet/debit
     *
     * @return array<string,mixed>
     */
    public function debit(array $data = []): array
    {
        return $this->client->request('POST', '/wallet/debit', $data);
    }

}
