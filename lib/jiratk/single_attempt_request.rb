# frozen_string_literal: true

require 'rest-client'

module JiraTk
  # Net::HTTP otherwise retries idempotent verbs (including DELETE) after some failures.
  class SingleAttemptRequest < RestClient::Request
    def net_http_object(hostname, port)
      super.tap { |http| http.max_retries = 0 }
    end
  end
end
