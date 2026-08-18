require "spec_helper"

# The transport's failure paths: what the client does with a plan refusal, a
# body that is not JSON, a socket that drops, and a retry budget of zero.
RSpec.describe "MisarMail error handling" do
  V1_ERR = "https://api.misar.io/mail/v1".freeze

  let(:client) { MisarMail::Client.new(api_key: "test-key", base_url: V1_ERR, max_retries: 1) }

  describe MisarMail::PlanLimitError do
    # A rate-limit 429 and a spent-allowance 429 look identical by status, so
    # the client reads the body to tell them apart. Getting this wrong means
    # retrying a call that cannot succeed until the plan changes.
    it "is raised instead of ApiError when the body carries the plan marker" do
      stub_request(:post, "#{V1_ERR}/send").to_return(
        status: 429,
        body: { "code" => "plan_limit_exceeded", "error" => "monthly sends spent" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
      expect { client.email.send(to: "a@b.com") }
        .to raise_error(MisarMail::PlanLimitError) { |e|
          expect(e.status).to eq(429)
          expect(e.error_type).to eq("plan_limit_exceeded")
          expect(e.message).to include("monthly sends spent")
        }
    end

    it "prefers the response headers over the upgrade offer in the body" do
      stub_request(:post, "#{V1_ERR}/dedicated-ips").to_return(
        status: 402,
        body: {
          "code" => "plan_limit_exceeded",
          "error" => "dedicated IPs are not on your plan",
          "upgrade" => {
            "currentPlanSlug" => "from_body",
            "feature" => "dedicated_ips",
            "urls" => { "pricing" => "https://body.example/pricing" }
          }
        }.to_json,
        headers: {
          "Content-Type" => "application/json",
          "X-Misar-Plan" => "starter",
          "X-Misar-Upgrade-Url" => "https://header.example/pricing",
          "Retry-After" => "120"
        }
      )
      expect { client.dedicated_ips.create(region: "us") }
        .to raise_error(MisarMail::PlanLimitError) { |e|
          expect(e.plan).to eq("starter")
          expect(e.upgrade_url).to eq("https://header.example/pricing")
          expect(e.retry_after).to eq(120)
          expect(e.feature).to eq("dedicated_ips")
        }
    end

    it "falls back to the upgrade offer when a proxy has stripped the headers" do
      stub_request(:get, "#{V1_ERR}/plan").to_return(
        status: 402,
        body: {
          "upgrade" => {
            "current_plan" => { "slug" => "free" },
            "feature" => "ai_subject_lines",
            "urls" => { "pricing" => "https://body.example/pricing" }
          }
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
      expect { client.plan.get }.to raise_error(MisarMail::PlanLimitError) { |e|
        expect(e.plan).to eq("free")
        expect(e.upgrade_url).to eq("https://body.example/pricing")
        expect(e.feature).to eq("ai_subject_lines")
        expect(e.retry_after).to be_nil
        # No "error" key in the body, so the client supplies the default.
        expect(e.message).to include("plan limit exceeded")
      }
    end

    it "ignores a non-numeric Retry-After rather than coercing it to zero" do
      stub_request(:get, "#{V1_ERR}/wallet").to_return(
        status: 429,
        body: { "error_type" => "plan_limit_exceeded", "error" => "spent" }.to_json,
        headers: { "Content-Type" => "application/json", "Retry-After" => "soon" }
      )
      expect { client.wallet.get }.to raise_error(MisarMail::PlanLimitError) { |e|
        expect(e.retry_after).to be_nil
        expect(e.plan).to be_nil
      }
    end

    it "is not retried — a spent allowance cannot recover within the budget" do
      stub = stub_request(:get, "#{V1_ERR}/warmup").to_return(
        status: 429,
        body: { "code" => "plan_limit_exceeded" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
      retrying = MisarMail::Client.new(api_key: "k", base_url: V1_ERR, max_retries: 3)
      allow(retrying).to receive(:sleep)
      expect { retrying.warmup.get }.to raise_error(MisarMail::PlanLimitError)
      expect(stub).to have_been_requested.once
    end
  end

  describe MisarMail::ApiError do
    it "reports the server's error message on a 4xx" do
      stub_request(:get, "#{V1_ERR}/keys/key_1")
        .to_return(status: 404, body: { "error" => "no such key" }.to_json,
                   headers: { "Content-Type" => "application/json" })
      expect { client.keys.get("key_1") }.to raise_error(MisarMail::ApiError) { |e|
        expect(e.status).to eq(404)
        expect(e.error_type).to eq("api_error")
        expect(e.message).to include("no such key")
      }
    end

    it "falls back to the message key when the body has no error key" do
      stub_request(:get, "#{V1_ERR}/wallet")
        .to_return(status: 422, body: { "message" => "bad request" }.to_json,
                   headers: { "Content-Type" => "application/json" })
      expect { client.wallet.get }.to raise_error(MisarMail::ApiError, /bad request/)
    end

    it "uses the raw body when the error response is not JSON at all" do
      stub_request(:get, "#{V1_ERR}/warmup").to_return(status: 500, body: "<html>gateway</html>")
      bad = MisarMail::Client.new(api_key: "k", base_url: V1_ERR, max_retries: 1)
      expect { bad.warmup.get }.to raise_error(MisarMail::ApiError, /gateway/)
    end

    describe ".from_response" do
      # A separate constructor used by callers holding a response object rather
      # than a parsed body; it duck-types on status/body/reason_phrase.
      let(:response) { Struct.new(:status, :body, :reason_phrase) }

      it "reads the error out of a JSON body" do
        err = described_class.from_response(response.new(403, { "error" => "forbidden" }.to_json, "Forbidden"))
        expect(err.status).to eq(403)
        expect(err.message).to include("forbidden")
      end

      it "falls back to the reason phrase when the body will not parse" do
        err = described_class.from_response(response.new(502, "not json", "Bad Gateway"))
        expect(err.status).to eq(502)
        expect(err.message).to include("Bad Gateway")
      end

      it "falls back again when there is no reason phrase either" do
        err = described_class.from_response(response.new(500, "", nil))
        expect(err.message).to include("unknown error")
      end
    end
  end

  describe "transport behaviour" do
    it "returns an empty hash for 204 No Content" do
      stub_request(:delete, "#{V1_ERR}/webhooks/wh_1").to_return(status: 204, body: "")
      expect(client.webhooks.delete("wh_1")).to eq({})
    end

    it "returns an empty hash when a 200 has no body" do
      stub_request(:get, "#{V1_ERR}/warmup").to_return(status: 200, body: "")
      expect(client.warmup.get).to eq({})
    end

    it "wraps a successful non-object JSON body under a data key" do
      stub_request(:get, "#{V1_ERR}/credit-rates")
        .to_return(status: 200, body: "[1,2,3]", headers: { "Content-Type" => "application/json" })
      expect(client.credit_rates.list).to eq("data" => [1, 2, 3])
    end

    it "wraps an unparseable 200 body rather than raising" do
      stub_request(:get, "#{V1_ERR}/wallet").to_return(status: 200, body: "not json at all")
      expect(client.wallet.get).to eq("data" => nil)
    end

    it "retries a dropped connection and then succeeds" do
      stub_request(:get, "#{V1_ERR}/warmup")
        .to_raise(Errno::ECONNRESET)
        .then.to_return(status: 200, body: { "stage" => 3 }.to_json,
                        headers: { "Content-Type" => "application/json" })
      retrying = MisarMail::Client.new(api_key: "k", base_url: V1_ERR, max_retries: 2)
      allow(retrying).to receive(:sleep)
      expect(retrying.warmup.get).to eq("stage" => 3)
    end

    it "raises NetworkError once the retry budget is spent" do
      stub_request(:get, "#{V1_ERR}/warmup").to_raise(SocketError.new("getaddrinfo failed"))
      retrying = MisarMail::Client.new(api_key: "k", base_url: V1_ERR, max_retries: 2)
      allow(retrying).to receive(:sleep)
      expect { retrying.warmup.get }.to raise_error(MisarMail::NetworkError) { |e|
        expect(e.status).to eq(0)
        expect(e.error_type).to eq("network_error")
        expect(e.message).to include("getaddrinfo failed")
      }
    end

    it "raises NetworkError on a read timeout" do
      stub_request(:post, "#{V1_ERR}/send").to_raise(Net::ReadTimeout)
      expect { client.email.send(to: "a@b.com") }.to raise_error(MisarMail::NetworkError)
    end

    it "gives up immediately when max_retries is zero" do
      # The retry loop never runs a single iteration, so nothing is sent and
      # the client reports the exhausted budget rather than hanging.
      no_budget = MisarMail::Client.new(api_key: "k", base_url: V1_ERR, max_retries: 0)
      expect { no_budget.warmup.get }.to raise_error(MisarMail::ApiError, /Max retries exceeded/)
    end

    it "supports PUT through the public request method" do
      stub = stub_request(:put, "#{V1_ERR}/anything")
             .with(body: { "a" => 1 })
             .to_return(status: 200, body: { "ok" => true }.to_json,
                        headers: { "Content-Type" => "application/json" })
      expect(client.request(:put, "/anything", { a: 1 })).to eq("ok" => true)
      expect(stub).to have_been_requested
    end

    it "rejects an HTTP verb it cannot build" do
      expect { client.request(:brew, "/anything") }
        .to raise_error(ArgumentError, /Unsupported HTTP method: brew/)
    end

    it "sends the API key as a bearer token on every call" do
      stub = stub_request(:get, "#{V1_ERR}/warmup")
             .with(headers: { "Authorization" => "Bearer test-key",
                              "Content-Type" => "application/json",
                              "Accept" => "application/json" })
             .to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })
      client.warmup.get
      expect(stub).to have_been_requested
    end

    it "joins base and path without doubling the slash" do
      trailing = MisarMail::Client.new(api_key: "k", base_url: "#{V1_ERR}/", max_retries: 1)
      stub = stub_request(:get, "#{V1_ERR}/warmup")
             .to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })
      trailing.warmup.get
      expect(stub).to have_been_requested
    end
  end

  describe "MisarMail.new" do
    it "is a shorthand for Client.new" do
      expect(MisarMail.new(api_key: "k")).to be_a(MisarMail::Client)
    end
  end
end
