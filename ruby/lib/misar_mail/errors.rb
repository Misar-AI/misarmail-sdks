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

  class NetworkError < ApiError
    def initialize(message, cause = nil)
      super(0, message, "network_error")
      @cause = cause
    end
  end
end
