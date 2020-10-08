# frozen-string-literal: true

require 'rest-client'

# Add class documentation
class ApiHelper
  def initialize(api_url)
    @api_url = api_url
    @resource = RestClient::Resource.new(
      api_url, user: USERNAME, password: PASSWORD
    )
  end

  def get(params)
    @resource.get(accept: :json, params: params) do |resp, req, res, &block|
      return resp if (200..499).include? resp.code

      resp.return!(req, res, &block)
    end
  end

  def post_client(params)
    RestClient::Request.new(
      url: @api_url, user: USERNAME, password: PASSWORD, payload: params.to_json, method: :post,
      headers: { content_type: 'application/json' }
    )
  end

  def post(params)
    post_client(params).execute do |response, request, _result, &block|
      puts "RESPONSE: #{response.code}"
      puts "RESPONSE BODY: #{response.body}"

      return response if (200..499).include? response.code

      response.return!(request, res, &block)
    end
  end
end
