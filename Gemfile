# frozen_string_literal: true

source 'https://rubygems.org'

ruby '>= 2.7.0'

# Web framework
gem 'sinatra', '~> 4.0'

# Database
gem 'sqlite3', '~> 1.7'
gem 'pg', '~> 1.5'

# JSON handling (included with sinatra-contrib)
gem 'sinatra-contrib', '~> 4.0'

# Prometheus metrics
gem 'prometheus-client', '~> 4.2'

# Web server
gem 'puma', '~> 6.4'

group :development, :test do
  gem 'rack-test', '~> 2.1'
  gem 'rerun', '~> 0.14' # Auto-reload on file changes
  gem 'rspec', '~> 3.13'
  gem 'rubocop', '~> 1.70', require: false
  gem 'rubocop-performance', require: false
  gem 'simplecov', '~> 0.22', require: false
end

gem 'rackup', '~> 2.3'
