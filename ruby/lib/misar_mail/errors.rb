module MisarMail
  class ApiError < StandardError
    attr_reader :status, :error_type

    def initialize(status, message, error_type = "api_error")
      @status = status
      @error_type = error_type
      super("misar-mail: API error #{status} (#{error_type}): #{message}")
    end

    def self.from_response(response)
      body = begin
        JSON.parse(response.body)
      rescue StandardError
        {}
      end
      new(response.status, body["error"] || response.reason_phrase || "unknown error")
    end
  end

  # Raised when the subscription attached to the API key blocks the call.
  #
  # MisarMail meters per-plan server-side: a spent allowance answers 429 and a
  # feature not on the plan answers 402. Raised as its own class rather than a
  # generic 429 because retrying cannot help until the allowance resets or the
  # plan changes — the client stops retrying on sight.
  class PlanLimitError < ApiError
    # @return [String, nil] the account's current plan slug
    attr_reader :plan
    # @return [String, nil] pricing page to send the user to
    attr_reader :upgrade_url
    # @return [Integer, nil] seconds until the allowance resets
    attr_reader :retry_after
    # @return [String, nil] the allowance that was exhausted
    attr_reader :feature

    def initialize(status, message, body = nil, headers = {})
      body    ||= {}
      headers   = (headers || {}).transform_keys { |k| k.to_s.downcase }
      offer     = body["upgrade"].is_a?(Hash) ? body["upgrade"] : {}
      # Headers are authoritative; the offer body is the fallback when a proxy
      # has stripped them.
      @plan        = headers["x-misar-plan"] || offer["currentPlanSlug"] ||
                     offer.dig("current_plan", "slug")
      @upgrade_url = headers["x-misar-upgrade-url"] || offer.dig("urls", "pricing")
      ra           = headers["retry-after"]
      @retry_after = ra.to_s.match?(/\A\d+\z/) ? ra.to_i : nil
      @feature     = offer["feature"]
      super(status, message, "plan_limit_exceeded")
    end
  end

  class NetworkError < ApiError
    def initialize(message, cause = nil)
      super(0, message, "network_error")
      @cause = cause
    end
  end
end
