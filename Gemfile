# frozen_string_literal: true

source 'https://rubygems.org'

ruby '3.2.2'

gemspec

gem 'awesome_print'

group :aws, :default do
  gem 'aws-sdk-athena'
  gem 'aws-sdk-s3'
end

gem 'flay'
# This is a cool gem but it has far too many
# dependencies for my taste.
# gem 'git-lint'

group :google, :default do
  gem 'google-api-client'
end

gem 'rest-client'

group :test do
  gem 'rspec'
end
gem 'rubocop'
gem 'rubocop-rspec'
gem 'runbook', github: 'doolin/runbook'
gem 'tty-prompt'
gem 'vcr'
gem 'webmock'

gem 'debug'
