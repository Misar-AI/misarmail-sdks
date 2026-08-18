# frozen_string_literal: true

require "cgi"

module MisarMail
  module Core
    # Query-string encoding shared by every generated GET/DELETE method.
    module Query
      # Returns "" for an empty bag so a generated call site can always append
      # unconditionally. Nil values are dropped so optional filters stay out of
      # the URL entirely rather than being sent as the string "".
      def self.encode(params)
        return "" if params.nil? || params.empty?

        pairs = params.reject { |_, v| v.nil? }
                      .map { |k, v| "#{CGI.escape(k.to_s)}=#{CGI.escape(v.to_s)}" }
        pairs.empty? ? "" : "?#{pairs.join('&')}"
      end
    end
  end
end
