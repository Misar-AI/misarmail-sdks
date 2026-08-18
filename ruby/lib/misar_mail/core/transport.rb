# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

require_relative "../errors"

module MisarMail
  module Core
    # HTTP transport shared by the generated resource layer.
    #
    # Everything the SDK does goes through one of three transports — HTTP for
    # REST, SSE for streaming, WebSocket for push — and all three authenticate
    # the same way: the account API key, sent as a bearer token. There is no
    # second credential path. What a key may do, and how much of it, is decided
    # server-side from the subscription behind that key.
    class Transport
      RETRYABLE_STATUSES = [429, 500, 502, 503, 504].freeze

      attr_reader :api_key, :base_url

      def initialize(api_key, base_url: "https://api.misar.io/mail", max_retries: 3, timeout: 30)
        raise ArgumentError, "A MisarMail API key is required" if api_key.nil? || api_key.empty?

        @api_key = api_key
        @base_url = base_url.chomp("/")
        @max_retries = max_retries
        @timeout = timeout
      end

      def request(method, path, body = nil)
        uri = URI.parse("#{@base_url}#{path}")
        attempt = 0

        loop do
          response = perform(uri, method, body)

          if RETRYABLE_STATUSES.include?(response.code.to_i) && attempt < @max_retries - 1
            sleep(backoff(attempt, response))
            attempt += 1
            next
          end

          return decode(response)
        rescue StandardError => e
          raise if e.is_a?(MisarMail::Error)

          if attempt < @max_retries - 1
            sleep(backoff(attempt))
            attempt += 1
            next
          end
          raise MisarMail::NetworkError.new(e.message)
        end
      end

      def headers
        {
          "Authorization" => "Bearer #{@api_key}",
          "Content-Type" => "application/json"
        }
      end

      private

      def perform(uri, method, body)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == "https"
        http.read_timeout = @timeout
        http.open_timeout = @timeout

        request_class = Net::HTTP.const_get(method.to_s.capitalize)
        req = request_class.new(uri.request_uri, headers)
        req.body = JSON.generate(body) unless body.nil?
        http.request(req)
      end

      def decode(response)
        status = response.code.to_i
        data = begin
          response.body.nil? || response.body.empty? ? {} : JSON.parse(response.body)
        rescue JSON::ParserError
          {}
        end

        if status >= 400
          message = data["error"] || data["message"] || response.message
          raise MisarMail::Error.new(status, message.to_s, data["error_type"] || "api_error", data)
        end

        data
      end

      # Exponential backoff, but honour Retry-After when the server sends one:
      # on a 429 the server knows when the window reopens, and guessing wastes
      # the caller's remaining budget.
      def backoff(attempt, response = nil)
        if response
          header = response["retry-after"]
          return [header.to_f, 60].min if header && header.to_f.positive?
        end
        0.2 * (2**attempt)
      end
    end
  end
end
