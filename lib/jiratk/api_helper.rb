# frozen_string_literal: true

require 'rest-client'

# Wrap the HTTP methods to make invocation much simpler and
# domain specific.
class ApiHelper
  def initialize(username = nil, password = nil)
    @username = username
    @password = password
  end

  def inspect
    "#<#{self.class}>"
  end

  def get(url, params, bearer_token: nil)
    resource = RestClient::Resource.new(
      url, user: @username, password: @password,
           max_redirects: 0, open_timeout: 10, read_timeout: 30
    )

    headers = { accept: :json, params: }
    headers[:authorization] = "Bearer #{bearer_token}" if bearer_token
    resource.get(headers) do |resp|
      return resp if (200..499).include? resp.code

      resp.return!
    end
  end

  # Updates are deliberately quiet: callers validate the response status.
  def put(url, params)
    RestClient::Request.execute(
      url: url, user: @username, password: @password,
      payload: params.to_json, method: :put,
      headers: { content_type: :json, accept: :json },
      max_redirects: 0, open_timeout: 10, read_timeout: 30
    ) { |response| response }
  end

  def post_client(url, params)
    RestClient::Request.new(
      url:, user: @username, password: @password, payload: params.to_json, method: :post,
      headers: { content_type: 'application/json' },
      max_redirects: 0, open_timeout: 10, read_timeout: 30
    )
  end

  def post(url, params, debug: true)
    post_client(url, params).execute do |response|
      if debug
        puts "RESPONSE: #{response.code}"
        puts "RESPONSE BODY: #{response.body}"
      end

      return response if (200..499).include? response.code

      response.return!
    end
  end
end
