<?php

declare(strict_types=1);

namespace MisarMail;

/**
 * emailAccounts — generated.
 */
class EmailAccountsResource
{
    public function __construct(private readonly Client $client) {}

    /**
     * GET /email-accounts
     *
     * @return array<string,mixed>
     */
    public function list(): array
    {
        return $this->client->request('GET', '/email-accounts');
    }

}
