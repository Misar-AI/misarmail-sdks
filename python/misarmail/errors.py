from __future__ import annotations

from typing import Any


class MisarMailError(Exception):
    def __init__(
        self,
        status: int,
        message: str,
        error_type: str = "api_error",
        details: Any | None = None,
    ) -> None:
        self.status = status
        self.error_type = error_type
        self.details = details
        super().__init__(f"misar-mail: API error {status} ({error_type}): {message}")

    @property
    def is_unauthorized(self) -> bool:
        """The key was rejected: missing, revoked, expired, or wrong product."""
        return self.status == 401

    @property
    def is_plan_denied(self) -> bool:
        """The key is valid but the account's subscription does not cover this call.

        Either the feature is not in the plan, a plan limit is exhausted, or a
        volume ceiling was hit. Gating is decided server-side from the
        subscription behind the key, so this is the signal to prompt an upgrade
        — without parsing error strings.
        """
        return self.status in (402, 403, 429)

    @property
    def is_retryable(self) -> bool:
        """Worth retrying as-is: transient server or rate-limit conditions."""
        return self.status == 429 or 500 <= self.status < 600


class MisarMailNetworkError(MisarMailError):
    def __init__(self, message: str, cause: Exception | None = None) -> None:
        self.cause = cause
        super().__init__(0, message, "network_error")


class MisarMailPlanLimitError(MisarMailError):
    """Raised when the subscription attached to the API key blocks the call.

    MisarMail meters per-plan server-side; a spent allowance answers 429 and a
    feature that is not on the plan answers 402. Both carry an upgrade offer.

    This is a distinct type rather than a generic 429 because retrying cannot
    help until the allowance resets or the plan changes — the client stops
    retrying as soon as it sees it. Surface ``upgrade_url`` to the user rather
    than reporting a bare failure.

    Attributes:
        plan: The account's current plan slug, when the API reports it.
        upgrade_url: Pricing page to send the user to.
        retry_after: Seconds until the allowance resets, when supplied.
        feature: The feature whose allowance was exhausted.
        payload: The decoded error body.
    """

    def __init__(self, status, message, payload=None, headers=None):
        h = {k.lower(): v for k, v in (headers or {}).items()}
        data = payload or {}
        offer = data.get("upgrade") if isinstance(data.get("upgrade"), dict) else {}
        # Headers are authoritative; the offer body is the fallback when a
        # proxy has stripped them.
        self.plan = h.get("x-misar-plan") or (offer.get("current_plan") or {}).get("slug") \
            or offer.get("currentPlanSlug")
        self.upgrade_url = h.get("x-misar-upgrade-url") or (offer.get("urls") or {}).get("pricing")
        retry = h.get("retry-after")
        self.retry_after = int(retry) if retry and str(retry).isdigit() else None
        self.feature = offer.get("feature")
        self.payload = data
        super().__init__(status, message, "plan_limit_exceeded")
