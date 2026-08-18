# frozen_string_literal: true

require "openssl"

module MisarMail
  # Inbound webhook signature verification.
  #
  # MisarMail signs each webhook as HMAC-SHA256(timestamp + "." + raw_body) with
  # the endpoint's signing secret, sending the digest in X-Misar-Signature and
  # the Unix timestamp in X-Misar-Timestamp.
  #
  # Verify against the RAW body, not a re-serialized hash: key order and
  # whitespace both change the digest. The comparison is constant-time so a
  # timing oracle cannot recover the digest byte by byte.
  module Webhooks
    DEFAULT_TOLERANCE_SECONDS = 300

    module_function

    # Returns true when the signature is authentic and the timestamp is fresh.
    # Never raises on malformed input — a bad signature is false, not an error.
    def verify(payload:, signature:, timestamp:, secret:, tolerance: DEFAULT_TOLERANCE_SECONDS)
      return false if [payload, signature, timestamp, secret].any? { |v| v.nil? || v.to_s.empty? }

      sent_at = Float(timestamp) rescue (return false)

      # Rejecting stale timestamps is what stops a captured request from being
      # replayed forever, so this is a real check rather than a formality.
      return false if (Time.now.to_f - sent_at).abs > tolerance

      secure_compare(sign(payload, timestamp, secret), signature.strip)
    end

    # Constant-time comparison. OpenSSL.fixed_length_secure_compare exists only
    # on newer Rubies and raises on length mismatch (which itself leaks length),
    # so compare lengths first and then XOR every byte regardless of where the
    # first difference is.
    def secure_compare(expected, actual)
      return false unless expected.bytesize == actual.bytesize

      difference = 0
      expected.bytes.zip(actual.bytes) { |a, b| difference |= a ^ b }
      difference.zero?
    end

    # Produces the digest MisarMail sends. Exported because verification is only
    # half the job: testing a webhook consumer needs a valid signature, and the
    # exact framing is where that usually goes wrong.
    def sign(payload, timestamp, secret)
      OpenSSL::HMAC.hexdigest("SHA256", secret, "#{timestamp}.#{payload}")
    end
  end
end
