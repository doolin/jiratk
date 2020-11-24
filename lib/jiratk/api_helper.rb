# frozen-string-literal: true

require 'rest-client'

# Add class documentation
class ApiHelper
  def initialize(username = nil, password = nil)
    @username = username
    @password = password
  end

  def get(url, params)
    resource = RestClient::Resource.new(
      url, user: @username, password: @password
    )

    resource.get(accept: :json, params: params) do |resp, req, res, &block|
      return resp if (200..499).include? resp.code

      resp.return!(req, res, &block)
    end
  end

  def post_client(url, params)
    RestClient::Request.new(
      url: url, user: @username, password: @password, payload: params.to_json, method: :post,
      headers: { content_type: 'application/json' }
    )
  end

  def post(url, params)
    post_client(url, params).execute do |response, request, _result, &block|
      puts "RESPONSE: #{response.code}"
      puts "RESPONSE BODY: #{response.body}"

      return response if (200..499).include? response.code

      response.return!(request, res, &block)
    end
  end
end
