# frozen-string-literal: true

require 'aws-sdk-athena'

# Simple wrapper for AWS S3 API.
class AthenaTools
  def region
    ENV['AWS_REGION']
  end

  def client(options = {})
    options[:region] = region
    @client ||= Aws::Athena::Client.new(options)
  end

  def execute(query)
    options = {
      query_string: query,
      query_execution_context: {
        database: 'jiratickets',
        catalog: 'AwsDataCatalog'
      },
      result_configuration: {
        output_location: 's3://inventium-testem/'
      },
      work_group: 'primary'
    }
    client.start_query_execution(options).query_execution_id
  end
end
