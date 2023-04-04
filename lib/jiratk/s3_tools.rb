# frozen_string_literal: true

require 'aws-sdk-s3'

# Simple wrapper for AWS S3 API.
class S3Tools
  def region
    ENV.fetch('AWS_REGION', nil)
  end

  def client(options = {})
    options[:region] = region
    @client ||= Aws::S3::Client.new(options)
  end

  def write(issue)
    client.put_object(bucket: 'inventium-jira', key: issue['key'], body: issue.to_json)
  end

  def get_object(options)
    client.get_object(options)
  end
end
