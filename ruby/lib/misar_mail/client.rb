require "net/http"
require "uri"
require "json"

module MisarMail
  BASE_URL     = "https://mail.misar.io/api/v1"
  BILLING_BASE = "https://mail.misar.io/api"
  RETRYABLE    = [429, 500, 502, 503, 504].freeze
  RETRY_BASE_S = 0.3

  # ── Resource base ────────────────────────────────────────────────────────────

  class Resource
    def initialize(client)
      @client = client
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
      @client.request(:get, "/contacts/#{id}")
    end

    def update(id, data)
      @client.request(:patch, "/contacts/#{id}", data)
    end

    def delete(id)
      @client.request(:delete, "/contacts/#{id}")
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
      @client.request(:get, "/domains")
    end

    def create(data)
      @client.request(:post, "/domains", data)
    end

    def get(id)
      @client.request(:get, "/domains/#{id}")
    end

    def verify(id)
      @client.request(:post, "/domains/#{id}/verify")
    end

    def delete(id)
      @client.request(:delete, "/domains/#{id}")
    end
  end

  # ── Resource: Aliases ────────────────────────────────────────────────────────

  class AliasesResource < Resource
    def list
      @client.request(:get, "/aliases")
    end

    def create(data)
      @client.request(:post, "/aliases", data)
    end

    def get(id)
      @client.request(:get, "/aliases/#{id}")
    end

    def update(id, data)
      @client.request(:patch, "/aliases/#{id}", data)
    end

    def delete(id)
      @client.request(:delete, "/aliases/#{id}")
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

  # ── Resource: Channels ───────────────────────────────────────────────────────

  class ChannelsResource < Resource
    def send_whatsapp(data)
      @client.request(:post, "/channels/whatsapp/send", data)
    end

    def send_push(data)
      @client.request(:post, "/channels/push/send", data)
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
      @client.request(:post, "/validate/email", { email: address })
    end
  end

  # ── Resource: Leads ──────────────────────────────────────────────────────────

  class LeadsResource < Resource
    def search(data)
      @client.request(:post, "/leads/search", data)
    end

    def get_job(id)
      @client.request(:get, "/leads/jobs/#{id}")
    end

    def list_jobs(params = {})
      qs = params.empty? ? "" : "?#{URI.encode_www_form(params)}"
      @client.request(:get, "/leads/jobs#{qs}")
    end

    def results(job_id)
      @client.request(:get, "/leads/jobs/#{job_id}/results")
    end

    def import_leads(data)
      @client.request(:post, "/leads/import", data)
    end

    def credits
      @client.request(:get, "/leads/credits")
    end
  end

  # ── Resource: Autopilot ──────────────────────────────────────────────────────

  class AutopilotResource < Resource
    def start(data)
      @client.request(:post, "/autopilot", data)
    end

    def get(id)
      @client.request(:get, "/autopilot/#{id}")
    end

    def list(params = {})
      qs = params.empty? ? "" : "?#{URI.encode_www_form(params)}"
      @client.request(:get, "/autopilot#{qs}")
    end

    def daily_plan
      @client.request(:get, "/autopilot/daily-plan")
    end
  end

  # ── Resource: Sales Agent ────────────────────────────────────────────────────

  class SalesAgentResource < Resource
    def get_config
      @client.request(:get, "/sales-agent/config")
    end

    def update_config(data)
      @client.request(:patch, "/sales-agent/config", data)
    end

    def get_actions(params = {})
      qs = params.empty? ? "" : "?#{URI.encode_www_form(params)}"
      @client.request(:get, "/sales-agent/actions#{qs}")
    end
  end

  # ── Resource: CRM ────────────────────────────────────────────────────────────

  class CrmResource < Resource
    def list_conversations(params = {})
      qs = params.empty? ? "" : "?#{URI.encode_www_form(params)}"
      @client.request(:get, "/crm/conversations#{qs}")
    end

    def get_conversation(id)
      @client.request(:get, "/crm/conversations/#{id}")
    end

    def update_conversation(id, data)
      @client.request(:patch, "/crm/conversations/#{id}", data)
    end

    def list_messages(conversation_id)
      @client.request(:get, "/crm/conversations/#{conversation_id}/messages")
    end

    def list_deals(params = {})
      qs = params.empty? ? "" : "?#{URI.encode_www_form(params)}"
      @client.request(:get, "/crm/deals#{qs}")
    end

    def create_deal(data)
      @client.request(:post, "/crm/deals", data)
    end

    def get_deal(id)
      @client.request(:get, "/crm/deals/#{id}")
    end

    def update_deal(id, data)
      @client.request(:patch, "/crm/deals/#{id}", data)
    end

    def delete_deal(id)
      @client.request(:delete, "/crm/deals/#{id}")
    end

    def list_clients(params = {})
      qs = params.empty? ? "" : "?#{URI.encode_www_form(params)}"
      @client.request(:get, "/crm/clients#{qs}")
    end

    def create_client(data)
      @client.request(:post, "/crm/clients", data)
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

  # ── Resource: Workspaces ─────────────────────────────────────────────────────

  class WorkspacesResource < Resource
    def list
      @client.request(:get, "/workspaces", {}, BILLING_BASE)
    end

    def create(data)
      @client.request(:post, "/workspaces", data, BILLING_BASE)
    end

    def get(id)
      @client.request(:get, "/workspaces/#{id}", {}, BILLING_BASE)
    end

    def update(id, data)
      @client.request(:patch, "/workspaces/#{id}", data, BILLING_BASE)
    end

    def delete(id)
      @client.request(:delete, "/workspaces/#{id}", {}, BILLING_BASE)
    end

    def list_members(ws_id)
      @client.request(:get, "/workspaces/#{ws_id}/members", {}, BILLING_BASE)
    end

    def invite_member(ws_id, data)
      @client.request(:post, "/workspaces/#{ws_id}/members", data, BILLING_BASE)
    end

    def update_member(ws_id, user_id, data)
      @client.request(:patch, "/workspaces/#{ws_id}/members/#{user_id}", data, BILLING_BASE)
    end

    def remove_member(ws_id, user_id)
      @client.request(:delete, "/workspaces/#{ws_id}/members/#{user_id}", {}, BILLING_BASE)
    end
  end

  # ── Main Client ──────────────────────────────────────────────────────────────

  class Client
    attr_reader :email, :contacts, :campaigns, :templates, :automations,
                :domains, :aliases, :dedicated_ips, :channels, :ab_tests,
                :sandbox, :inbound, :analytics, :track, :keys, :validate,
                :leads, :autopilot, :sales_agent, :crm, :webhooks, :usage,
                :billing, :workspaces

    def initialize(api_key:, timeout: 30, max_retries: 3)
      @api_key     = api_key
      @timeout     = timeout
      @max_retries = max_retries

      @email         = EmailResource.new(self)
      @contacts      = ContactsResource.new(self)
      @campaigns     = CampaignsResource.new(self)
      @templates     = TemplatesResource.new(self)
      @automations   = AutomationsResource.new(self)
      @domains       = DomainsResource.new(self)
      @aliases       = AliasesResource.new(self)
      @dedicated_ips = DedicatedIpsResource.new(self)
      @channels      = ChannelsResource.new(self)
      @ab_tests      = AbTestsResource.new(self)
      @sandbox       = SandboxResource.new(self)
      @inbound       = InboundResource.new(self)
      @analytics     = AnalyticsResource.new(self)
      @track         = TrackResource.new(self)
      @keys          = KeysResource.new(self)
      @validate      = ValidateResource.new(self)
      @leads         = LeadsResource.new(self)
      @autopilot     = AutopilotResource.new(self)
      @sales_agent   = SalesAgentResource.new(self)
      @crm           = CrmResource.new(self)
      @webhooks      = WebhooksResource.new(self)
      @usage         = UsageResource.new(self)
      @billing       = BillingResource.new(self)
      @workspaces    = WorkspacesResource.new(self)
    end

    # @param method [Symbol] :get, :post, :patch, :put, :delete
    # @param path   [String] e.g. "/contacts"
    # @param data   [Hash]   request body (post/put/patch only)
    # @param base   [String] override base URL (for billing/workspaces)
    # @return [Hash]
    # @raise [ApiError, NetworkError]
    def request(method, path, data = {}, base = BASE_URL)
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
