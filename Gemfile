# frozen_string_literal: true

source 'https://rubygems.org'

ruby '>= 4.0.1'

gemspec

gem 'awesome_print'
gem 'cgi'
gem 'csv'
gem 'pstore'
gem 'rest-client'
gem 'runbook', github: 'doolin/runbook'
gem 'tsort'
gem 'tty-prompt'

group :aws, :default do
  gem 'aws-sdk-athena'
  gem 'aws-sdk-s3'
end

group :google, :default do
  gem 'google-api-client'
  gem 'multi_json' # Required by the Google client's Representable JSON adapter.
end

group :development do
  gem 'bundler-audit', require: false
  gem 'debug'
  gem 'flay'
  gem 'rubocop'
  gem 'rubocop-rspec'
end

group :test do
  gem 'rspec'
  gem 'simplecov', '~> 0.22.0', require: false
  gem 'vcr'
  gem 'webmock'
end
