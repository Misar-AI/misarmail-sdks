package misarmail

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"math"
	"strconv"
	"time"
)

// DefaultWebhookTolerance is the accepted clock skew for a webhook timestamp.
const DefaultWebhookTolerance = 300 * time.Second

// VerifyWebhookSignature reports whether a webhook is authentic and fresh.
//
// MisarMail signs each webhook as HMAC-SHA256(timestamp + "." + rawBody) with
// the endpoint's signing secret, sending the digest in X-Misar-Signature and
// the Unix timestamp in X-Misar-Timestamp.
//
// Verify against the RAW body, not a re-marshalled struct: key order and
// whitespace both change the digest. The comparison is constant-time so a
// timing oracle cannot recover the digest byte by byte.
func VerifyWebhookSignature(payload []byte, signature, timestamp, secret string, tolerance time.Duration) bool {
	if len(payload) == 0 || signature == "" || timestamp == "" || secret == "" {
		return false
	}

	sentAt, err := strconv.ParseFloat(timestamp, 64)
	if err != nil {
		return false
	}

	// Rejecting stale timestamps is what stops a captured request from being
	// replayed forever, so this is a real check rather than a formality.
	if tolerance <= 0 {
		tolerance = DefaultWebhookTolerance
	}
	skew := math.Abs(float64(time.Now().Unix()) - sentAt)
	if skew > tolerance.Seconds() {
		return false
	}

	return hmac.Equal([]byte(SignWebhook(payload, timestamp, secret)), []byte(signature))
}

// SignWebhook produces the digest MisarMail sends in X-Misar-Signature.
//
// Exported because verification is only half the job: anyone writing tests for
// a webhook consumer needs to produce a valid signature, and reimplementing the
// exact framing (timestamp + "." + body) is where that usually goes wrong.
func SignWebhook(payload []byte, timestamp, secret string) string {
	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write([]byte(timestamp))
	mac.Write([]byte("."))
	mac.Write(payload)
	return hex.EncodeToString(mac.Sum(nil))
}
