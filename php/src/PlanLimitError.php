<?php

declare(strict_types=1);

namespace MisarMail;

/**
 * Thrown when the subscription attached to the API key blocks the call.
 *
 * MisarMail meters per-plan server-side: a spent allowance answers 429 and a
 * feature not on the plan answers 402. A distinct class rather than a generic
 * 429 because retrying cannot help until the allowance resets or the plan
 * changes — the client stops retrying on sight.
 */
class PlanLimitError extends ApiError
{
    public function __construct(
        string $message,
        int $status,
        /** The account's current plan slug. */
        public readonly ?string $plan = null,
        /** Pricing page to send the user to. */
        public readonly ?string $upgradeUrl = null,
        /** Seconds until the allowance resets. */
        public readonly ?int $retryAfter = null,
        /** The allowance that was exhausted. */
        public readonly ?string $feature = null,
    ) {
        parent::__construct($message, $status);
    }
}
