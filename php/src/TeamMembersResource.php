<?php

declare(strict_types=1);

namespace MisarMail;

/**
 * teamMembers — generated.
 */
class TeamMembersResource
{
    public function __construct(private readonly Client $client) {}

    /**
     * GET /team-members
     *
     * @return array<string,mixed>
     */
    public function get(?string $owner_id = null): array
    {
        $q = array_filter([
            'owner_id' => $owner_id,
        ], static fn ($v) => $v !== null);
        return $this->client->request('GET', '/team-members' . ($q === [] ? '' : '?' . http_build_query($q)));
    }

}
