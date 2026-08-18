<?php

declare(strict_types=1);

namespace MisarMail;

// ── Main Client ───────────────────────────────────────────────────────────────


/**
 * Live subscription standing for the key's owner.
 *
 * Read this before an expensive call rather than discovering the ceiling
 * through a PlanLimitError: `usage` reports every metered feature and
 * `upgrade` is non-null as soon as one of them is spent.
 */
class PlanResource
{
    public function __construct(private readonly Client $client) {}

    /**
     * GET /plan — plan, sending allowances, per-feature usage, upgrade offer.
     *
     * @return array<string,mixed>
     */
    public function get(): array
    {
        return $this->client->request('GET', '/plan');
    }

    /**
     * GET /monetization/stats — revenue and monetization counters.
     *
     * @return array<string,mixed>
     */
    public function monetization(): array
    {
        return $this->client->request('GET', '/monetization/stats');
    }
}
