require "spec_helper"

RSpec.describe MisarMail::Client do
  let(:base_url) { "https://mail.misar.io/api/v1" }
  let(:client) { described_class.new(api_key: "test-key", base_url: base_url, max_retries: 1) }

  def stub_get(path, status:, body:)
    stub_request(:get, "#{base_url}#{path}")
      .to_return(status: status, body: body.to_json, headers: { "Content-Type" => "application/json" })
  end

  def stub_post(path, status:, body:)
    stub_request(:post, "#{base_url}#{path}")
      .to_return(status: status, body: body.to_json, headers: { "Content-Type" => "application/json" })
  end

  it "send_email returns id" do
    stub_post("/send", status: 200, body: { "id" => "msg_1", "status" => "queued" })
    resp = client.send_email({ to: "a@b.com", subject: "Hi", html: "<p>Hi</p>" })
    expect(resp["id"]).to eq("msg_1")
  end

  it "contacts_list returns collection" do
    stub_get("/contacts", status: 200, body: { "contacts" => [], "total" => 0 })
    resp = client.contacts_list
    expect(resp["total"]).to eq(0)
  end

  it "contacts_create returns new contact" do
    stub_post("/contacts", status: 200, body: { "id" => "c_1", "email" => "x@y.com" })
    resp = client.contacts_create({ email: "x@y.com" })
    expect(resp["id"]).to eq("c_1")
  end

  it "analytics_get returns metrics" do
    stub_get("/analytics", status: 200, body: { "sent" => 100, "opens" => 40 })
    resp = client.analytics_get
    expect(resp["sent"]).to eq(100)
  end

  it "campaigns_list returns collection" do
    stub_get("/campaigns", status: 200, body: { "campaigns" => [], "total" => 0 })
    resp = client.campaigns_list
    expect(resp["campaigns"]).to eq([])
  end

  it "validate_email returns valid flag" do
    stub_post("/validate", status: 200, body: { "valid" => true, "email" => "a@b.com" })
    resp = client.validate_email({ email: "a@b.com" })
    expect(resp["valid"]).to be true
  end

  it "raises ApiError on 401" do
    stub_post("/send", status: 401, body: { "error" => "Unauthorized" })
    expect { client.send_email({ to: "a@b.com" }) }
      .to raise_error(MisarMail::ApiError) { |e| expect(e.status).to eq(401) }
  end

  it "retries on 503 and succeeds" do
    client_retries = described_class.new(api_key: "k", base_url: base_url, max_retries: 2)
    stub_request(:post, "#{base_url}/send")
      .to_return(
        { status: 503, body: { "error" => "down" }.to_json, headers: { "Content-Type" => "application/json" } },
        { status: 200, body: { "id" => "msg_retry" }.to_json, headers: { "Content-Type" => "application/json" } }
      )
    allow(client_retries).to receive(:sleep)
    resp = client_retries.send_email({ to: "a@b.com" })
    expect(resp["id"]).to eq("msg_retry")
  end

  it "raises NetworkError on connection failure" do
    stub_request(:post, "#{base_url}/send").to_raise(Faraday::ConnectionFailed.new("refused"))
    expect { client.send_email({ to: "a@b.com" }) }.to raise_error(MisarMail::NetworkError)
  end
end
