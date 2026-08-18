class MisarMailError(Exception):
    def __init__(self, status: int, message: str, error_type: str = "api_error"):
        self.status = status
        self.error_type = error_type
        super().__init__(f"misar-mail: API error {status} ({error_type}): {message}")


class MisarMailNetworkError(MisarMailError):
    def __init__(self, message: str, cause: Exception | None = None):
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
