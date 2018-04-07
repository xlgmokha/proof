# frozen_string_literal: true

source 'https://rubygems.org'

git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?("/")
  "https://github.com/#{repo_name}.git"
end

gem 'activerecord-session_store'
gem 'bcrypt', '~> 3.1.7'
gem 'coffee-rails', '~> 4.2'
gem 'dotenv-rails'
gem 'email_validator'
gem 'jbuilder', '~> 2.5'
gem 'jwt'
gem 'puma', '~> 3.7'
gem 'rails', '~> 5.1.4'
gem 'rotp'
gem 'saml-kit', '~> 1.0'
gem 'sass-rails', '~> 5.0'
gem 'scim-shady', '~> 0.2'
gem 'spank'
gem 'therubyracer', platforms: :ruby
gem 'turbolinks', '~> 5'
gem 'webpacker'
# gem 'redis', '~> 3.0'

group :development do
  gem 'brakeman'
  gem 'bundler-audit'
  gem 'listen', '>= 3.0.5', '< 3.2'
  gem 'rubocop'
  gem 'spring'
  gem 'spring-watcher-listen', '~> 2.0.0'
  gem 'web-console', '>= 3.3.0'
end

group :development, :test do
  gem 'byebug', platforms: [:mri, :mingw, :x64_mingw]
  gem 'capybara', '~> 2.13'
  gem 'factory_bot_rails'
  gem 'ffaker'
  gem 'rails-controller-testing'
  gem 'rspec-rails', '~> 3.6'
  gem 'selenium-webdriver'
  gem 'sqlite3'
  gem 'webmock'
end

group :production do
  gem 'pg'
  gem 'rails_12factor'
end
