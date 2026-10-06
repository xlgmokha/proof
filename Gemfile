# frozen_string_literal: true

source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }
ruby RUBY_VERSION

gem 'activerecord-session_store'
gem 'audited'
gem 'bcrypt'
gem 'bootsnap', require: false
gem 'browser'
gem 'dotenv'
gem 'email_validator'
gem 'flipper'
gem 'flipper-active_record'
gem 'flutie'
gem 'jbuilder'
gem 'jwt'
gem 'local_time'
gem 'pg'
gem 'puma'
gem 'rails'
gem 'rotp'
gem 'saml-kit'
gem 'scim-kit'
gem 'shakapacker'
gem 'spank'
gem 'turbolinks'
gem 'varkon'
group :doc do
  gem 'jekyll'
  gem 'minima' # This is the default theme for new Jekyll sites.
end
group :development do
  gem 'brakeman'
  gem 'bundler-audit'
  gem 'erb_lint', require: false
  gem 'listen'
  gem 'rubocop', require: false
  gem 'rubocop-rails', require: false
  gem 'web-console'
end
group :development, :test do
  gem 'byebug', platforms: [:mri, :mingw, :x64_mingw]
  gem 'i18n-tasks'
  gem 'rspec-rails'
  gem 'vcr'
end
group :test do
  gem 'capybara'
  gem 'capybara-screenshot'
  gem 'factory_bot_rails'
  gem 'ffaker'
  gem 'rubocop-rspec'
  gem 'selenium-webdriver'
  gem 'webmock'
end
