require "erb"
require "net/http"
require "uri"
require "json"

require_relative "core/query"

module MisarMail
  BASE_URL     = "https://api.misar.io/mail/v1"
  API_BASE     = "https://api.misar.io/mail"
  BILLING_BASE = "https://api.misar.io/mail"
  RETRYABLE    = [429, 500, 502, 503, 504].freeze
  RETRY_BASE_S = 0.3

  # ── Resource base ────────────────────────────────────────────────────────────

  class Resource
    def initialize(client)
      @client = client
    end

    private

    # Every generated method that takes optional filters builds its path as
    # query(compact(...)), but neither helper had a definition anywhere in the
    # gem — so DmarcResource#check, EmailsResource#list, RevenueResource
    # #attribution, SegmentsResource#members, SubscriptionResource#get,
    # TeamMembersResource#get and DmarcResource#remove_domain all raised
    # NoMethodError the moment they were called. Core::Query.encode was written
    # to be "shared by every generated GET/DELETE method" and already drops
    # nils; it was simply never wired up.
    def compact(params)
      params.reject { |_, v| v.nil? }
    end

    def query(params)
      Core::Query.encode(params)
    end
  end

  # ── Resource: Email ──────────────────────────────────────────────────────────

  class EmailResource < Resource
    def send(data)
      @client.request(:post, "/send", data)
    end
  end

  # ── Resource: Contacts ───────────────────────────────────────────────────────

  class ContactsResource < Resource
    def list(page: 1, limit: 20)
      @client.request(:get, "/contacts?#{URI.encode_www_form(page: page, limit: limit)}")
    end

    def create(data)
      @client.request(:post, "/contacts", data)
    end

    def get(id)
      @client.request(:get, "/contacts?id=#{ERB::Util.url_encode(id)}")
    end

    def update(email, data)
      @client.request(:patch, "/contacts", data.merge(email: email))
    end

    def delete(id)
      @client.request(:delete, "/contacts?id=#{ERB::Util.url_encode(id)}")
    end

    def import_contacts(data)
      @client.request(:post, "/contacts/import", data)
    end
  end

  # ── Resource: Campaigns ──────────────────────────────────────────────────────

  class CampaignsResource < Resource
    def list(params = {})
      qs = params.empty? ? "" : "?#{URI.encode_www_form(params)}"
      @client.request(:get, "/campaigns#{qs}")
    end

    def create(data)
      @client.request(:post, "/campaigns", data)
    end

    def get(id)
      @client.request(:get, "/campaigns/#{id}")
    end

    def update(id, data)
      @client.request(:patch, "/campaigns/#{id}", data)
    end

    def send(id)
      @client.request(:post, "/campaigns/#{id}/send")
    end

    def delete(id)
      @client.request(:delete, "/campaigns/#{id}")
    end
  end

  # ── Resource: Templates ──────────────────────────────────────────────────────

  class TemplatesResource < Resource
    def list
      @client.request(:get, "/templates")
    end

    def create(data)
      @client.request(:post, "/templates", data)
    end

    def get(id)
      @client.request(:get, "/templates/#{id}")
    end

    def update(id, data)
      @client.request(:patch, "/templates/#{id}", data)
    end

    def delete(id)
      @client.request(:delete, "/templates/#{id}")
    end

    def render(data)
      @client.request(:post, "/templates/render", data)
    end
  end

  # ── Resource: Automations ────────────────────────────────────────────────────

  class AutomationsResource < Resource
    def list(params = {})
      qs = params.empty? ? "" : "?#{URI.encode_www_form(params)}"
      @client.request(:get, "/automations#{qs}")
    end

    def create(data)
      @client.request(:post, "/automations", data)
    end

    def get(id)
      @client.request(:get, "/automations/#{id}")
    end

    def update(id, data)
      @client.request(:patch, "/automations/#{id}", data)
    end

    def delete(id)
      @client.request(:delete, "/automations/#{id}")
    end

    def activate(id, active:)
      @client.request(:post, "/automations/#{id}/activate", { active: active })
    end
  end

  # ── Resource: Domains ────────────────────────────────────────────────────────

  class DomainsResource < Resource
    def list
      @client.request(:get, "/domains", {}, API_BASE)
    end

    def create(data)
      @client.request(:post, "/domains", data, API_BASE)
    end

    def get(id)
      @client.request(:get, "/domains/#{id}", {}, API_BASE)
    end

    def verify(id)
      @client.request(:post, "/domains/#{id}/verify", {}, API_BASE)
    end

    def delete(id)
      @client.request(:delete, "/domains/#{id}", {}, API_BASE)
    end
  end


  # ── Resource: Dedicated IPs ──────────────────────────────────────────────────

  class DedicatedIpsResource < Resource
    def list
      @client.request(:get, "/dedicated-ips")
    end

    def create(data)
      @client.request(:post, "/dedicated-ips", data)
    end

    def update(id, data)
      @client.request(:patch, "/dedicated-ips/#{id}", data)
    end

    def delete(id)
      @client.request(:delete, "/dedicated-ips/#{id}")
    end
  end


  # ── Resource: A/B Tests ──────────────────────────────────────────────────────

  class AbTestsResource < Resource
    def list
      @client.request(:get, "/ab-tests")
    end

    def create(data)
      @client.request(:post, "/ab-tests", data)
    end

    def get(id)
      @client.request(:get, "/ab-tests/#{id}")
    end

    def set_winner(id, variant_id)
      @client.request(:post, "/ab-tests/#{id}/winner", { variant_id: variant_id })
    end
  end

  # ── Resource: Sandbox ────────────────────────────────────────────────────────

  class SandboxResource < Resource
    def send(data)
      @client.request(:post, "/sandbox/send", data)
    end

    def list(params = {})
      qs = params.empty? ? "" : "?#{URI.encode_www_form(params)}"
      @client.request(:get, "/sandbox#{qs}")
    end

    def delete(id)
      @client.request(:delete, "/sandbox/#{id}")
    end
  end

  # ── Resource: Inbound ────────────────────────────────────────────────────────

  class InboundResource < Resource
    def list(params = {})
      qs = params.empty? ? "" : "?#{URI.encode_www_form(params)}"
      @client.request(:get, "/inbound#{qs}")
    end

    def create(data)
      @client.request(:post, "/inbound", data)
    end

    def get(id)
      @client.request(:get, "/inbound/#{id}")
    end

    def delete(id)
      @client.request(:delete, "/inbound/#{id}")
    end
  end

  # ── Resource: Analytics ──────────────────────────────────────────────────────

  class AnalyticsResource < Resource
    def overview(params = {})
      qs = params.empty? ? "" : "?#{URI.encode_www_form(params)}"
      @client.request(:get, "/analytics#{qs}")
    end
  end

  # ── Resource: Track ──────────────────────────────────────────────────────────

  class TrackResource < Resource
    def event(data)
      @client.request(:post, "/track/event", data)
    end

    def purchase(data)
      @client.request(:post, "/track/purchase", data)
    end
  end

  # ── Resource: API Keys ───────────────────────────────────────────────────────

  class KeysResource < Resource
    def list
      @client.request(:get, "/keys")
    end

    def create(data)
      @client.request(:post, "/keys", data)
    end

    def get(id)
      @client.request(:get, "/keys/#{id}")
    end

    def revoke(id)
      @client.request(:delete, "/keys/#{id}")
    end
  end

  # ── Resource: Validate ───────────────────────────────────────────────────────

  class ValidateResource < Resource
    def email(address)
      @client.request(:post, "/validate", { email: address })
    end
  end

  # ── Resource: Webhooks ───────────────────────────────────────────────────────

  class WebhooksResource < Resource
    def list
      @client.request(:get, "/webhooks")
    end

    def create(data)
      @client.request(:post, "/webhooks", data)
    end

    def get(id)
      @client.request(:get, "/webhooks/#{id}")
    end

    def update(id, data)
      @client.request(:patch, "/webhooks/#{id}", data)
    end

    def delete(id)
      @client.request(:delete, "/webhooks/#{id}")
    end

    def test(id)
      @client.request(:post, "/webhooks/#{id}/test")
    end
  end

  # ── Resource: Usage ──────────────────────────────────────────────────────────

  class UsageResource < Resource
    def get(params = {})
      qs = params.empty? ? "" : "?#{URI.encode_www_form(params)}"
      @client.request(:get, "/usage#{qs}")
    end
  end

  # ── Resource: Billing ────────────────────────────────────────────────────────

  class BillingResource < Resource
    def subscription
      @client.request(:get, "/billing/subscription", {}, BILLING_BASE)
    end

    def checkout(data)
      @client.request(:post, "/billing/checkout", data, BILLING_BASE)
    end
  end


  # ── Main Client ──────────────────────────────────────────────────────────────

  # Live subscription standing for the key's owner.
  #
  # Read this before an expensive call rather than discovering the ceiling
  # through a PlanLimitError: +usage+ reports every metered feature and
  # +upgrade+ is non-nil as soon as one of them is spent.
  class PlanResource < Resource
    # GET /plan — plan, sending allowances, per-feature usage, upgrade offer.
    def get
      @client.request(:get, "/plan")
    end

    # GET /monetization/stats — revenue and monetization counters.
    def monetization
      @client.request(:get, "/monetization/stats")
    end
  end


  # ── Generated from scripts/sdk-endpoint-spec.json ──────────────────────────
  #
  # These twenty endpoints were missing from every SDK except TypeScript.

  class AiResource < Resource
    # POST /ai/subject-lines
    def subject_lines(data: {})
      @client.request(:post, "/ai/subject-lines", data)
    end

  end

  class CreditRatesResource < Resource
    # GET /credit-rates
    def list
      @client.request(:get, "/credit-rates")
    end

  end

  class DeliverabilityResource < Resource
    # GET /deliverability/audit
    def audit
      @client.request(:get, "/deliverability/audit")
    end

    # GET /deliverability/score
    def score
      @client.request(:get, "/deliverability/score")
    end

  end

  class DmarcResource < Resource
    # GET /dmarc/check
    def check(domain: nil, dkim_selector: nil)
      @client.request(:get, "/dmarc/check#{query(compact(domain: domain, dkim_selector: dkim_selector))}")
    end

    # GET /dmarc/domains
    def list_domains
      @client.request(:get, "/dmarc/domains")
    end

    # POST /dmarc/domains
    def add_domain(data: {})
      @client.request(:post, "/dmarc/domains", data)
    end

    # DELETE /dmarc/domains
    def remove_domain(domain_id: nil)
      @client.request(:delete, "/dmarc/domains#{query(compact(domain_id: domain_id))}")
    end

  end

  class EmailAccountsResource < Resource
    # GET /email-accounts
    def list
      @client.request(:get, "/email-accounts")
    end

  end

  class EmailsResource < Resource
    # GET /emails
    def list(folder: nil, search: nil, limit: nil)
      @client.request(:get, "/emails#{query(compact(folder: folder, search: search, limit: limit))}")
    end

    # GET /emails/:id
    def get(id)
      @client.request(:get, "/emails/#{id}")
    end

    # PATCH /emails/:id
    def update(id, data: {})
      @client.request(:patch, "/emails/#{id}", data)
    end

  end

  class LandingPagesResource < Resource
    # POST /landing-pages
    def create(data: {})
      @client.request(:post, "/landing-pages", data)
    end

  end

  class MonetizationResource < Resource
    # POST /monetization/tip
    def tip(data: {})
      @client.request(:post, "/monetization/tip", data)
    end

  end

  class RevenueResource < Resource
    # GET /revenue/attribution
    def attribution(campaign_id: nil, period: nil)
      @client.request(:get, "/revenue/attribution#{query(compact(campaign_id: campaign_id, period: period))}")
    end

  end

  class SegmentsResource < Resource
    # GET /segments/:id/members
    def members(id, page: nil, limit: nil)
      @client.request(:get, "/segments/#{id}/members#{query(compact(page: page, limit: limit))}")
    end

  end

  class SubscriptionResource < Resource
    # GET /subscription
    def get(product: nil)
      @client.request(:get, "/subscription#{query(compact(product: product))}")
    end

    # POST /subscription
    def upsert(data: {})
      @client.request(:post, "/subscription", data)
    end

    # DELETE /subscription
    def cancel(data: {})
      @client.request(:delete, "/subscription", data)
    end

  end

  class TeamMembersResource < Resource
    # GET /team-members
    def get(owner_id: nil)
      @client.request(:get, "/team-members#{query(compact(owner_id: owner_id))}")
    end

  end

  class WalletResource < Resource
    # GET /wallet
    def get
      @client.request(:get, "/wallet")
    end

    # POST /wallet/credit
    def credit(data: {})
      @client.request(:post, "/wallet/credit", data)
    end

    # POST /wallet/debit
    def debit(data: {})
      @client.request(:post, "/wallet/debit", data)
    end

  end

  class WarmupResource < Resource
    # GET /warmup
    def get
      @client.request(:get, "/warmup")
    end

  end

  # One decoded SSE frame.
  #
  # MisarMail emits unnamed frames — +data: {...}+ with no +event:+ line — so
  # +event+ is normally nil. +data+ is the decoded JSON; +raw+ is always the
  # payload exactly as received.
  StreamEvent = Struct.new(:event, :data, :raw)

  # The two Server-Sent Events endpoints.
  #
  # Both live outside +/v1+, so they use API_BASE. Both are API-key
  # authenticated and metered, so a plan refusal on open raises PlanLimitError
  # exactly as a non-streaming call would.
  class StreamingResource < Resource
    # POST /api/ai/generate-email/stream — token-by-token generation.
    #
    #   mail.streaming.generate_email(prompt: "...") do |frame|
    #     print frame.data["delta"]
    #   end
    #
    # Returns an Enumerator when no block is given.
    def generate_email(**options, &block)
      @client.sse_stream(:post, "/ai/generate-email/stream", options, &block)
    end

    # GET /api/campaigns/{id}/send-stream — live send progress.
    def campaign_send(campaign_id, &block)
      path = "/campaigns/#{ERB::Util.url_encode(campaign_id)}/send-stream"
      @client.sse_stream(:get, path, nil, &block)
    end
  end

  class Client
    attr_reader :plan, :streaming, :ai, :credit_rates, :deliverability, :dmarc, :email_accounts, :emails, :landing_pages, :monetization, :revenue, :segments, :subscription, :team_members, :wallet, :warmup
    attr_reader :email, :contacts, :campaigns, :templates, :automations,
                :domains, :dedicated_ips, :ab_tests,
                :sandbox, :inbound, :analytics, :track, :keys, :validate,
                :webhooks, :usage,
                :billing

    # @param base_url [String] override the API host — point it at a stub
    #   server in tests, or at a self-hosted deployment. Defaults to BASE_URL.
    def initialize(api_key:, timeout: 30, max_retries: 3, base_url: BASE_URL)
      @api_key     = api_key
      @timeout     = timeout
      @max_retries = max_retries
      @base_url    = base_url

      @plan          = PlanResource.new(self)
      @streaming     = StreamingResource.new(self)
      @ai = AiResource.new(self)
      @credit_rates = CreditRatesResource.new(self)
      @deliverability = DeliverabilityResource.new(self)
      @dmarc = DmarcResource.new(self)
      @email_accounts = EmailAccountsResource.new(self)
      @emails = EmailsResource.new(self)
      @landing_pages = LandingPagesResource.new(self)
      @monetization = MonetizationResource.new(self)
      @revenue = RevenueResource.new(self)
      @segments = SegmentsResource.new(self)
      @subscription = SubscriptionResource.new(self)
      @team_members = TeamMembersResource.new(self)
      @wallet = WalletResource.new(self)
      @warmup = WarmupResource.new(self)
      @email         = EmailResource.new(self)
      @contacts      = ContactsResource.new(self)
      @campaigns     = CampaignsResource.new(self)
      @templates     = TemplatesResource.new(self)
      @automations   = AutomationsResource.new(self)
      @domains       = DomainsResource.new(self)
      @dedicated_ips = DedicatedIpsResource.new(self)
      @ab_tests      = AbTestsResource.new(self)
      @sandbox       = SandboxResource.new(self)
      @inbound       = InboundResource.new(self)
      @analytics     = AnalyticsResource.new(self)
      @track         = TrackResource.new(self)
      @keys          = KeysResource.new(self)
      @validate      = ValidateResource.new(self)
      @webhooks      = WebhooksResource.new(self)
      @usage         = UsageResource.new(self)
      @billing       = BillingResource.new(self)
    end

    # @param method [Symbol] :get, :post, :patch, :put, :delete
    # @param path   [String] e.g. "/contacts"
    # @param data   [Hash]   request body (post/put/patch only)
    # @param base   [String] override base URL (for billing/workspaces)
    # @return [Hash]
    # @raise [ApiError, NetworkError]
    def request(method, path, data = {}, base = nil)
      base ||= @base_url
      url      = URI.parse(base.chomp("/") + "/" + path.delete_prefix("/"))
      has_body = !data.empty? && %i[post put patch].include?(method)
      json_body = has_body ? JSON.generate(data) : nil

      last_status = 0

      @max_retries.times do |attempt|
        begin
          http              = Net::HTTP.new(url.host, url.port)
          http.use_ssl      = url.scheme == "https"
          http.open_timeout = 10
          http.read_timeout = @timeout

          req = build_request(method, url, json_body)
          resp = http.request(req)
          last_status = resp.code.to_i

          # A rate-limit 429 and a spent-allowance 429 are identical by
          # status, so the body decides. Only the first is worth retrying.
          if plan_limit?(resp)
            raise PlanLimitError.new(
              last_status,
              plan_limit_message(resp),
              parse_body(resp),
              response_headers(resp),
            )
          end

          if RETRYABLE.include?(last_status) && attempt < @max_retries - 1
            sleep(RETRY_BASE_S * (2**attempt))
            next
          end

          return parse_response(resp, last_status)

        rescue Net::OpenTimeout, Net::ReadTimeout,
               Errno::ECONNREFUSED, Errno::ECONNRESET, SocketError => e
          if attempt < @max_retries - 1
            sleep(RETRY_BASE_S * (2**attempt))
            next
          end
          raise NetworkError.new(e.message, e)
        end
      end

      raise ApiError.new(last_status, "Max retries exceeded")
    end


    # Opens an SSE connection and yields each decoded frame.
    #
    # Deliberately not retried: replaying a stream that failed mid-flight would
    # duplicate whatever the caller already consumed.
    #
    # @yieldparam [StreamEvent] frame
    # @return [Enumerator] when no block is given
    def sse_stream(method, path, data = nil, &block)
      return enum_for(:sse_stream, method, path, data) unless block_given?

      url = URI.parse(API_BASE + path)
      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = url.scheme == "https"
      http.read_timeout = @timeout

      req = build_request(method, url, data.nil? ? nil : JSON.generate(data))
      req["Accept"] = "text/event-stream"

      http.request(req) do |resp|
        status = resp.code.to_i
        unless (200..299).cover?(status)
          raw = resp.read_body.to_s
          body = begin
            JSON.parse(raw)
          rescue JSON::ParserError
            {}
          end
          if body["code"] == "plan_limit_exceeded" || body["upgrade"].is_a?(Hash)
            raise PlanLimitError.new(status, body["error"] || "plan limit exceeded",
                                     body, response_headers(resp))
          end
          raise ApiError.new(status, body["error"] || (raw.empty? ? "stream error" : raw))
        end

        buffer = +""
        event_name = nil
        data_lines = []

        flush = lambda do
          next nil if data_lines.empty?

          raw = data_lines.join("\n")
          name = event_name
          data_lines = []
          event_name = nil
          next :done if raw == "[DONE]"

          decoded = begin
            JSON.parse(raw)
          rescue JSON::ParserError
            nil
          end
          StreamEvent.new(name, decoded, raw)
        end

        resp.read_body do |chunk|
          buffer << chunk
          # A frame ends at a blank line; split on it and keep the remainder.
          while (idx = buffer.index("\n\n") || buffer.index("\r\n\r\n"))
            frame = buffer.slice!(0, idx)
            buffer.sub!(/\A(\r?\n){1,2}/, "")

            frame.split(/\r?\n/).each do |line|
              next if line.empty? || line.start_with?(":") # keepalive

              if line.start_with?("event:")
                event_name = line.delete_prefix("event:").strip
              elsif line.start_with?("data:")
                data_lines << line.delete_prefix("data:").delete_prefix(" ")
              end
            end

            result = flush.call
            return if result == :done

            yield result if result
          end
        end

        # A trailing frame with no closing blank line.
        buffer.split(/\r?\n/).each do |line|
          next if line.empty? || line.start_with?(":")

          if line.start_with?("event:")
            event_name = line.delete_prefix("event:").strip
          elsif line.start_with?("data:")
            data_lines << line.delete_prefix("data:").delete_prefix(" ")
          end
        end
        tail = flush.call
        yield tail if tail && tail != :done
      end
    end

    private

    def build_request(method, url, json_body)
      klass = case method
              when :get    then Net::HTTP::Get
              when :post   then Net::HTTP::Post
              when :patch  then Net::HTTP::Patch
              when :put    then Net::HTTP::Put
              when :delete then Net::HTTP::Delete
              else raise ArgumentError, "Unsupported HTTP method: #{method}"
              end

      req = klass.new(url.request_uri)
      req["Authorization"] = "Bearer #{@api_key}"
      req["Content-Type"]  = "application/json"
      req["Accept"]        = "application/json"
      req.body = json_body if json_body
      req
    end

    # True when the body carries the API's plan-refusal marker.
    def plan_limit?(resp)
      body = parse_body(resp)
      body["code"] == "plan_limit_exceeded" ||
        body["error_type"] == "plan_limit_exceeded" ||
        body["upgrade"].is_a?(Hash)
    end

    def plan_limit_message(resp)
      parse_body(resp)["error"] || "plan limit exceeded"
    end

    # Always a Hash. Both callers index it by string key, and a top-level JSON
    # array is a shape this API really returns — parse_response has always had
    # a branch for it. Returning the raw Array here made plan_limit? raise
    # "TypeError: no implicit conversion of String into Integer" before
    # parse_response ever got to use that branch, so an array response could
    # not be delivered at all.
    def parse_body(resp)
      return {} if resp.body.nil? || resp.body.empty?

      decoded = JSON.parse(resp.body)
      decoded.is_a?(Hash) ? decoded : {}
    rescue JSON::ParserError
      {}
    end

    def response_headers(resp)
      resp.each_header.to_h
    rescue StandardError
      {}
    end

    def parse_response(resp, status)
      return {} if status == 204 || resp.body.nil? || resp.body.empty?

      decoded = begin
        JSON.parse(resp.body)
      rescue JSON::ParserError
        nil
      end

      if status >= 400
        msg = decoded.is_a?(Hash) ? (decoded["error"] || decoded["message"] || resp.body) : resp.body
        raise ApiError.new(status, msg)
      end

      decoded.is_a?(Hash) ? decoded : { "data" => decoded }
    end
  end
end
