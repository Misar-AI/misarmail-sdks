<?php

declare(strict_types=1);

namespace MisarMail;

/**
 * One decoded SSE frame.
 *
 * MisarMail emits unnamed frames — `data: {...}` with no `event:` line — so
 * $event is normally null. $data is the decoded JSON; $raw is always the
 * payload exactly as received.
 */
final class StreamEvent
{
    /**
     * @param array<string,mixed>|null $data
     */
    public function __construct(
        public readonly ?string $event,
        public readonly ?array $data,
        public readonly string $raw,
    ) {}
}
