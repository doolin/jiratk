require 'rest-client'

class ApiHelper
  def initialize(api_url)
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
end