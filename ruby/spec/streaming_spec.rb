require "spec_helper"

# Client#sse_stream is the one piece of transport the resource wrappers do not
# share, and it is hand-rolled frame parsing — buffering, blank-line framing,
# CRLF, keepalive comments, a [DONE] sentinel, and a trailing frame with no
# terminator. Every one of those is a place a stream can silently truncate.
#
# Both streaming endpoints hang off API_BASE, which is a constant rather than
# the client's base_url, so base_url: does not redirect them.
RSpec.describe MisarMail::StreamingResource do
  STREAM_BASE = "https://api.misar.io/mail".freeze
  GENERATE    = "#{STREAM_BASE}/ai/generate-email/stream".freeze

  let(:client) { MisarMail::Client.new(api_key: "test-key", max_retries: 1) }

  def sse(body)
    { status: 200, body: body, headers: { "Content-Type" => "text/event-stream" } }
  end

  def collect(&block)
    frames = []
    block.call(frames)
    frames
  end

  it "yields one decoded frame per event and stops at the sentinel" do
    stub_request(:post, GENERATE)
      .to_return(sse(%(data: {"delta":"He"}\n\ndata: {"delta":"llo"}\n\ndata: [DONE]\n\n)))
    frames = collect { |f| client.streaming.generate_email(prompt: "hi") { |frame| f << frame } }
    expect(frames.map { |f| f.data["delta"] }).to eq(%w[He llo])
    expect(frames.first).to be_a(MisarMail::StreamEvent)
  end

  it "posts the keyword arguments as the JSON request body" do
    stub = stub_request(:post, GENERATE)
           .with(body: { "prompt" => "write a welcome email", "tone" => "warm" },
                 headers: { "Accept" => "text/event-stream",
                            "Authorization" => "Bearer test-key" })
           .to_return(sse("data: [DONE]\n\n"))
    client.streaming.generate_email(prompt: "write a welcome email", tone: "warm") { |_| }
    expect(stub).to have_been_requested
  end

  it "drops everything after the sentinel" do
    stub_request(:post, GENERATE)
      .to_return(sse(%(data: {"delta":"a"}\n\ndata: [DONE]\n\ndata: {"delta":"never"}\n\n)))
    frames = collect { |f| client.streaming.generate_email { |frame| f << frame } }
    expect(frames.length).to eq(1)
  end

  it "keeps the event name when the server sends one" do
    stub_request(:post, GENERATE)
      .to_return(sse(%(event: progress\ndata: {"pct":50}\n\ndata: [DONE]\n\n)))
    frames = collect { |f| client.streaming.generate_email { |frame| f << frame } }
    expect(frames.first.event).to eq("progress")
    expect(frames.first.data).to eq("pct" => 50)
  end

  it "ignores keepalive comment frames instead of yielding empty events" do
    stub_request(:post, GENERATE)
      .to_return(sse(%(: keepalive\n\ndata: {"delta":"x"}\n\n: ping\n\ndata: [DONE]\n\n)))
    frames = collect { |f| client.streaming.generate_email { |frame| f << frame } }
    expect(frames.length).to eq(1)
    expect(frames.first.data).to eq("delta" => "x")
  end

  it "handles CRLF framing" do
    stub_request(:post, GENERATE)
      .to_return(sse(%(data: {"delta":"a"}\r\n\r\ndata: {"delta":"b"}\r\n\r\ndata: [DONE]\r\n\r\n)))
    frames = collect { |f| client.streaming.generate_email { |frame| f << frame } }
    expect(frames.map { |x| x.data["delta"] }).to eq(%w[a b])
  end

  it "keeps a malformed frame as raw text rather than discarding the stream" do
    stub_request(:post, GENERATE)
      .to_return(sse(%(data: {not json}\n\ndata: {"delta":"b"}\n\ndata: [DONE]\n\n)))
    frames = collect { |f| client.streaming.generate_email { |frame| f << frame } }
    expect(frames.first.data).to be_nil
    expect(frames.first.raw).to eq("{not json}")
    expect(frames.last.data).to eq("delta" => "b")
  end

  it "emits a trailing frame that never got its closing blank line" do
    # A stream cut short by the server still delivers what it managed to send.
    stub_request(:post, GENERATE).to_return(sse(%(data: {"delta":"a"}\n\ndata: {"delta":"tail"})))
    frames = collect { |f| client.streaming.generate_email { |frame| f << frame } }
    expect(frames.map { |x| x.data["delta"] }).to eq(%w[a tail])
  end

  it "keeps the event name on a trailing frame as well" do
    stub_request(:post, GENERATE)
      .to_return(sse(%(data: {"delta":"a"}\n\nevent: done\ndata: {"total":1})))
    frames = collect { |f| client.streaming.generate_email { |frame| f << frame } }
    expect(frames.last.event).to eq("done")
    expect(frames.last.data).to eq("total" => 1)
  end

  it "joins a multi-line data payload before decoding it" do
    stub_request(:post, GENERATE)
      .to_return(sse(%(data: {"delta":\ndata: "split"}\n\ndata: [DONE]\n\n)))
    frames = collect { |f| client.streaming.generate_email { |frame| f << frame } }
    expect(frames.first.data).to eq("delta" => "split")
  end

  it "returns an Enumerator when called without a block" do
    expect(client.streaming.generate_email(prompt: "x")).to be_a(Enumerator)
  end

  describe "campaign_send" do
    it "GETs the campaign's send-stream and yields progress frames" do
      stub = stub_request(:get, "#{STREAM_BASE}/campaigns/cmp_1/send-stream")
             .to_return(sse(%(data: {"sent":1}\n\ndata: {"sent":2}\n\ndata: [DONE]\n\n)))
      frames = collect { |f| client.streaming.campaign_send("cmp_1") { |frame| f << frame } }
      expect(frames.map { |x| x.data["sent"] }).to eq([1, 2])
      expect(stub).to have_been_requested
    end

    it "percent-encodes a campaign id with reserved characters" do
      stub = stub_request(:get, "#{STREAM_BASE}/campaigns/a%2Fb/send-stream")
             .to_return(sse("data: [DONE]\n\n"))
      client.streaming.campaign_send("a/b") { |_| }
      expect(stub).to have_been_requested
    end
  end

  describe "failures on open" do
    it "raises ApiError when the stream is refused" do
      stub_request(:post, GENERATE)
        .to_return(status: 400, body: { "error" => "prompt required" }.to_json,
                   headers: { "Content-Type" => "application/json" })
      expect { client.streaming.generate_email { |_| } }
        .to raise_error(MisarMail::ApiError) { |e|
          expect(e.status).to eq(400)
          expect(e.message).to include("prompt required")
        }
    end

    it "raises ApiError with the raw body when the refusal is not JSON" do
      stub_request(:post, GENERATE).to_return(status: 502, body: "upstream is down")
      expect { client.streaming.generate_email { |_| } }
        .to raise_error(MisarMail::ApiError, /upstream is down/)
    end

    it "reports a plan refusal as PlanLimitError, not a generic ApiError" do
      stub_request(:post, GENERATE).to_return(
        status: 402,
        body: {
          "code" => "plan_limit_exceeded",
          "error" => "AI generation is not on your plan",
          "upgrade" => { "feature" => "ai_generate", "urls" => { "pricing" => "https://x/p" } }
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
      expect { client.streaming.generate_email { |_| } }
        .to raise_error(MisarMail::PlanLimitError) { |e|
          expect(e.feature).to eq("ai_generate")
          expect(e.upgrade_url).to eq("https://x/p")
        }
    end

    it "raises a default-message ApiError when the refusal body is empty" do
      stub_request(:get, "#{STREAM_BASE}/campaigns/cmp_1/send-stream").to_return(status: 500, body: "")
      expect { client.streaming.campaign_send("cmp_1") { |_| } }
        .to raise_error(MisarMail::ApiError, /stream error/)
    end
  end
end
