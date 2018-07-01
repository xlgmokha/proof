# frozen_string_literal: true

source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }
ruby '2.5.1'

gem 'activerecord-session_store'
gem 'bcrypt', '~> 3.1'
gem 'bootsnap', '>= 1.1.0', require: false
gem 'coffee-rails', '~> 4.2'
gem 'dotenv'
gem 'email_validator'
gem 'foreman'
gem 'jbuilder', '~> 2.5'
gem 'jwt'
gem 'puma', '~> 3.11'
gem 'rails', '~> 5.2.0'
gem 'rotp'
gem 'saml-kit', '~> 1.0'
gem 'sass-rails', '~> 5.0'
gem 'scim-shady', '~> 0.2'
gem 'spank'
gem 'therubyracer', platforms: :ruby
gem 'turbolinks', '~> 5'
gem 'uglifier', '>= 1.3.0'
gem 'webpacker'
# gem 'redis', '~> 4.0'

group :development do
  gem 'brakeman'
  gem 'bundler-audit'
  gem 'listen', '>= 3.0.5', '< 3.2'
  gem 'rubocop'
  gem 'web-console', '>= 3.3.0'
end

group :development, :test do
  gem 'byebug', platforms: [:mri, :mingw, :x64_mingw]
  gem 'capybara', '>= 2.15', '< 4.0'
  gem 'capybara-screenshot'
  gem 'chromedriver-helper'
  gem 'factory_bot_rails'
  gem 'ffaker'
  gem 'rails-controller-testing'
  gem 'rspec-rails', '~> 3.7'
  gem 'selenium-webdriver'
  gem 'sqlite3'
  gem 'webmock'
end

group :production do
  gem 'pg'
  gem 'rails_12factor'
end
