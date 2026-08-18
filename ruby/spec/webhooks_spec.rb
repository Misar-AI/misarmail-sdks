require "spec_helper"

# Signature verification is the one part of this gem an attacker interacts with
# directly, so every rejection branch is worth pinning: a wrong secret, a
# replayed timestamp, a truncated digest, and junk input that must return false
# rather than blow up in the consumer's request handler.
RSpec.describe MisarMail::Webhooks do
  let(:secret)    { "whsec_test" }
  let(:payload)   { '{"event":"email.delivered","id":"evt_1"}' }
  let(:timestamp) { Time.now.to_i.to_s }
  let(:signature) { described_class.sign(payload, timestamp, secret) }

  describe ".sign" do
    it "signs timestamp + '.' + raw body with HMAC-SHA256" do
      expected = OpenSSL::HMAC.hexdigest("SHA256", secret, "#{timestamp}.#{payload}")
      expect(described_class.sign(payload, timestamp, secret)).to eq(expected)
    end

    it "produces a different digest when the body changes by one byte" do
      other = described_class.sign(payload.sub("evt_1", "evt_2"), timestamp, secret)
      expect(other).not_to eq(signature)
    end
  end

  describe ".verify" do
    it "accepts a signature it just produced" do
      expect(described_class.verify(payload: payload, signature: signature,
                                    timestamp: timestamp, secret: secret)).to be true
    end

    it "tolerates surrounding whitespace on the header value" do
      expect(described_class.verify(payload: payload, signature: "  #{signature}\n",
                                    timestamp: timestamp, secret: secret)).to be true
    end

    it "rejects a signature made with a different secret" do
      forged = described_class.sign(payload, timestamp, "whsec_wrong")
      expect(described_class.verify(payload: payload, signature: forged,
                                    timestamp: timestamp, secret: secret)).to be false
    end

    it "rejects a body that was altered after signing" do
      expect(described_class.verify(payload: '{"event":"email.bounced"}', signature: signature,
                                    timestamp: timestamp, secret: secret)).to be false
    end

    it "rejects a digest of the wrong length without raising" do
      expect(described_class.verify(payload: payload, signature: signature[0, 10],
                                    timestamp: timestamp, secret: secret)).to be false
    end

    it "rejects a timestamp older than the tolerance window" do
      stale = (Time.now.to_i - 600).to_s
      expect(described_class.verify(payload: payload, signature: described_class.sign(payload, stale, secret),
                                    timestamp: stale, secret: secret)).to be false
    end

    it "rejects a timestamp far in the future too" do
      ahead = (Time.now.to_i + 600).to_s
      expect(described_class.verify(payload: payload, signature: described_class.sign(payload, ahead, secret),
                                    timestamp: ahead, secret: secret)).to be false
    end

    it "accepts a stale timestamp when the caller widens the tolerance" do
      stale = (Time.now.to_i - 600).to_s
      expect(described_class.verify(payload: payload, signature: described_class.sign(payload, stale, secret),
                                    timestamp: stale, secret: secret, tolerance: 3600)).to be true
    end

    it "returns false rather than raising on a non-numeric timestamp" do
      expect(described_class.verify(payload: payload, signature: signature,
                                    timestamp: "not-a-time", secret: secret)).to be false
    end

    [:payload, :signature, :timestamp, :secret].each do |field|
      it "returns false when #{field} is nil" do
        args = { payload: payload, signature: signature, timestamp: timestamp, secret: secret }
        expect(described_class.verify(**args.merge(field => nil))).to be false
      end

      it "returns false when #{field} is empty" do
        args = { payload: payload, signature: signature, timestamp: timestamp, secret: secret }
        expect(described_class.verify(**args.merge(field => ""))).to be false
      end
    end
  end

  describe ".secure_compare" do
    it "is true only for identical strings" do
      expect(described_class.secure_compare("abc", "abc")).to be true
      expect(described_class.secure_compare("abc", "abd")).to be false
      expect(described_class.secure_compare("abc", "abcd")).to be false
    end
  end
end
