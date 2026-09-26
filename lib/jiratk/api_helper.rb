# frozen_string_literal: true

require 'rest-client'

# Wrap the HTTP methods to make invocation much simpler and
# domain specific.
class ApiHelper
  def initialize(username = nil, password = nil)
    @username = username
    @password = password
  end

  def get(url, params)
    resource = RestClient::Resource.new(
      url, user: @username, password: @password,
           max_redirects: 0, open_timeout: 10, read_timeout: 30
    )

    resource.get(accept: :json, params:) do |resp, req, res, &block|
      return resp if (200..499).include? resp.code

      resp.return!(req, res, &block)
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
    post_client(url, params).execute do |response, request, result, &block|
      if debug
        puts "RESPONSE: #{response.code}"
        puts "RESPONSE BODY: #{response.body}"
      end

      return response if (200..499).include? response.code

      response.return!(request, result, &block)
    end
  end
end
