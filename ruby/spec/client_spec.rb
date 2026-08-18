require "spec_helper"

# These cases were written against a flat API — client.send_email,
# client.contacts_list — that this SDK does not have and, judging by the
# resource classes, never had. Every call is routed through a resource object
# instead: client.email.send, client.contacts.list. The HTTP paths they assert
# were already correct, so only the call sites moved.
RSpec.describe MisarMail::Client do
  let(:base_url) { "https://api.misar.io/mail/v1" }
  let(:client) { described_class.new(api_key: "test-key", base_url: base_url, max_retries: 1) }

  def stub_get(path, status:, body:)
    stub_request(:get, "#{base_url}#{path}")
      .to_return(status: status, body: body.to_json, headers: { "Content-Type" => "application/json" })
  end

  def stub_post(path, status:, body:)
    stub_request(:post, "#{base_url}#{path}")
      .to_return(status: status, body: body.to_json, headers: { "Content-Type" => "application/json" })
  end

  it "email.send returns id" do
    stub_post("/send", status: 200, body: { "id" => "msg_1", "status" => "queued" })
    resp = client.email.send({ to: "a@b.com", subject: "Hi", html: "<p>Hi</p>" })
    expect(resp["id"]).to eq("msg_1")
  end

  it "contacts.list returns collection" do
    # list appends page/limit, so match the path and ignore the query.
    stub_request(:get, "#{base_url}/contacts").with(query: hash_including({}))
      .to_return(status: 200, body: { "contacts" => [], "total" => 0 }.to_json,
                 headers: { "Content-Type" => "application/json" })
    resp = client.contacts.list
    expect(resp["total"]).to eq(0)
  end

  it "contacts.create returns new contact" do
    stub_post("/contacts", status: 200, body: { "id" => "c_1", "email" => "x@y.com" })
    resp = client.contacts.create({ email: "x@y.com" })
    expect(resp["id"]).to eq("c_1")
  end

  it "analytics.overview returns metrics" do
    stub_request(:get, %r{#{Regexp.escape(base_url)}/analytics})
      .to_return(status: 200, body: { "sent" => 100, "opens" => 40 }.to_json,
                 headers: { "Content-Type" => "application/json" })
    resp = client.analytics.overview
    expect(resp["sent"]).to eq(100)
  end

  it "campaigns.list returns collection" do
    stub_request(:get, %r{#{Regexp.escape(base_url)}/campaigns})
      .to_return(status: 200, body: { "campaigns" => [], "total" => 0 }.to_json,
                 headers: { "Content-Type" => "application/json" })
    resp = client.campaigns.list
    expect(resp["campaigns"]).to eq([])
  end

  it "validate.email returns valid flag" do
    stub_post("/validate", status: 200, body: { "valid" => true, "email" => "a@b.com" })
    resp = client.validate.email({ email: "a@b.com" })
    expect(resp["valid"]).to be true
  end

  it "raises ApiError on 401" do
    stub_post("/send", status: 401, body: { "error" => "Unauthorized" })
    expect { client.email.send({ to: "a@b.com" }) }
      .to raise_error(MisarMail::ApiError) { |e| expect(e.status).to eq(401) }
  end

  it "retries on 503 and succeeds" do
    client_retries = described_class.new(api_key: "k", base_url: base_url, max_retries: 2)
    stub_request(:post, "#{base_url}/send")
      .to_return(
        { status: 503, body: { "error" => "down" }.to_json, headers: { "Content-Type" => "application/json" } },
        { status: 200, body: { "id" => "msg_retry" }.to_json, headers: { "Content-Type" => "application/json" } }
      )
    # The backoff sleeps inside the client, so stub it on the client itself
    # rather than on the resource wrapper that delegates to it.
    allow(client_retries).to receive(:sleep)
    resp = client_retries.email.send({ to: "a@b.com" })
    expect(resp["id"]).to eq("msg_retry")
  end

  it "raises NetworkError on connection failure" do
    # Net::HTTP, not Faraday — faraday is not a dependency of this gem, and the
    # client rescues Errno::ECONNREFUSED among others.
    stub_request(:post, "#{base_url}/send").to_raise(Errno::ECONNREFUSED)
    expect { client.email.send({ to: "a@b.com" }) }.to raise_error(MisarMail::NetworkError)
  end

  # Regression: parse_response short-circuited on an empty body *before* looking at
  # the status, so an error with nothing in it returned {} and read as success. A
  # bare 401 and anything a proxy strips both arrive this way.
  [401, 403, 404].each do |code|
    it "raises on #{code} even when the body is empty" do
      stub_request(:post, "#{base_url}/send").to_return(status: code, body: "")
      expect { client.email.send({ to: "a@b.com" }) }
        .to raise_error(MisarMail::ApiError) { |e| expect(e.status).to eq(code) }
    end
  end

  it "still returns {} for a successful empty body" do
    stub_request(:post, "#{base_url}/send").to_return(status: 204, body: "")
    expect(client.email.send({ to: "a@b.com" })).to eq({})
  end
end
