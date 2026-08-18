package misarmail

import "fmt"

// Error is returned for any non-2xx response, and for transport failures with
// Status 0.
type Error struct {
	Status    int
	Message   string
	ErrorType string
	Details   map[string]any
}

func (e *Error) Error() string {
	return fmt.Sprintf("misarmail: API error %d (%s): %s", e.Status, e.ErrorType, e.Message)
}

// IsUnauthorized reports that the key was rejected outright — missing, revoked,
// expired, or issued for a different product.
func (e *Error) IsUnauthorized() bool { return e.Status == 401 }

// IsPlanDenied reports that the key is valid but the account's subscription
// does not cover this call: the feature is not in the plan, a plan limit is
// exhausted, or a volume ceiling was hit. Gating is decided server-side from
// the subscription behind the key, so this is the signal to prompt an upgrade
// rather than to retry.
func (e *Error) IsPlanDenied() bool {
	return e.Status == 402 || e.Status == 403 || e.Status == 429
}

// IsRetryable reports a transient condition worth retrying as-is.
func (e *Error) IsRetryable() bool {
	return e.Status == 429 || (e.Status >= 500 && e.Status < 600)
}
