# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

module MisarMail
  module Core
    # Server-Sent Events client for the MisarMail streaming endpoints.
    #
    # Both streams frame events as "data: <json>" and close with the sentinel
    # "data: [DONE]". One of the two is a POST, so this reads the response body
    # incrementally rather than using an EventSource-style helper.
    module SSE
      DONE = "[DONE]"

      module_function

      # Yields one decoded payload per event until the stream terminates.
      def stream(url, api_key, method: "GET", body: nil)
        return enum_for(:stream, url, api_key, method: method, body: body) unless block_given?

        uri = URI.parse(url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == "https"
        http.read_timeout = 300

        headers = {
          "Authorization" => "Bearer #{api_key}",
          "Accept" => "text/event-stream"
        }
        headers["Content-Type"] = "application/json" unless body.nil?

        request = Net::HTTP.const_get(method.capitalize).new(uri.request_uri, headers)
        request.body = JSON.generate(body) unless body.nil?

        http.request(request) do |response|
          # Errors arrive as a normal JSON body, not as an SSE frame.
          if response.code.to_i >= 400
            data = begin
              JSON.parse(response.read_body)
            rescue StandardError
              {}
            end
            raise MisarMail::Error.new(response.code.to_i, data["error"].to_s, "api_error", data)
          end

          buffer = +""
          response.read_body do |chunk|
            buffer << chunk
            while (index = buffer.index("\n"))
              line = buffer.slice!(0..index).chomp
              next unless line.start_with?("data:")

              payload = line[5..].strip
              return if payload == DONE
              next if payload.empty?

              begin
                yield JSON.parse(payload)
              rescue JSON::ParserError
                # One malformed frame should not discard everything already
                # streamed.
                yield({ "raw" => payload })
              end
            end
          end
        end
      end
    end
  end
end
