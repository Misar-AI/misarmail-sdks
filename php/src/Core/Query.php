<?php

declare(strict_types=1);

namespace MisarMail\Core;

/** Query-string encoding shared by every generated GET/DELETE method. */
final class Query
{
    /**
     * Returns '' for an empty bag so a generated call site can always append
     * unconditionally. Null values are dropped so optional filters stay out of
     * the URL entirely rather than being sent as an empty string.
     *
     * @param array<string, scalar|null> $params
     */
    public static function encode(array $params): string
    {
        $filtered = array_filter($params, static fn ($value) => $value !== null);
        if ($filtered === []) {
            return '';
        }

        return '?' . http_build_query($filtered);
    }
}
