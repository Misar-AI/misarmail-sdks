<?php

declare(strict_types=1);

namespace MisarMail;

// ── Resource: Billing ─────────────────────────────────────────────────────────

class BillingResource
{
    private const BILLING_BASE = 'https://api.misar.io/mail';

    public function __construct(private readonly Client $client) {}

    public function subscription(): array
    {
        return $this->client->request('GET', '/billing/subscription', [], self::BILLING_BASE);
    }

    public function checkout(array $data): array
    {
        return $this->client->request('POST', '/billing/checkout', $data, self::BILLING_BASE);
    }
}
