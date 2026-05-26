# frozen_string_literal: true

require 'simplecov'
SimpleCov.start do
  add_filter '/spec/'
end

require 'fileutils'

ENV['RACK_ENV'] = 'test'
TEST_DB_PATH = File.expand_path('../tmp/test.db', __dir__)
FileUtils.mkdir_p(File.dirname(TEST_DB_PATH))
FileUtils.rm_f(TEST_DB_PATH)
ENV['DATABASE_PATH'] = TEST_DB_PATH

require_relative '../server'
require 'rack/test'

RSpec.configure do |config|
  config.include Rack::Test::Methods

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups

  config.after(:suite) do
    FileUtils.rm_f(TEST_DB_PATH)
  end
end

def app
  Sinatra::Application
end
