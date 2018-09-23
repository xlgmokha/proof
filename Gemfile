# frozen_string_literal: true

source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }
ruby '2.5.1'

gem 'activerecord-session_store', '~> 1.1'
gem 'audited', '~> 4.8'
gem 'bcrypt', '~> 3.1'
gem 'bootsnap', '>= 1.1.0', require: false
gem 'coffee-rails', '~> 4.2'
gem 'dotenv', '~> 2.5'
gem 'email_validator', '~> 1.6'
gem 'flipper', '~> 0.16'
gem 'flipper-active_record', '~> 0.16'
gem 'foreman', '~> 0.85'
gem 'jbuilder', '~> 2.5'
gem 'jwt', '~> 2.1'
gem 'local_time', '~> 2.1'
gem 'puma', '~> 3.11'
gem 'rails', '~> 5.2.0'
gem 'rotp', '~> 3.3'
gem 'saml-kit', '~> 1.0'
gem 'sass-rails', '~> 5.0'
gem 'scim-shady', '~> 0.2'
gem 'spank', '~> 1.0'
gem 'turbolinks', '~> 5'
gem 'uglifier', '>= 1.3.0'
gem 'webpacker', '~> 3.5'
# gem 'redis', '~> 4.0'
group :development do
  gem 'brakeman', '~> 4.3'
  gem 'bundler-audit', '~> 0.6'
  gem 'listen', '>= 3.0.5', '< 3.2'
  gem 'rubocop', '~> 0.58'
  gem 'web-console', '>= 3.3.0'
end
group :development, :test do
  gem 'byebug', platforms: [:mri, :mingw, :x64_mingw]
  gem 'capybara', '~> 3.6'
  gem 'capybara-screenshot', '~> 1.0'
  gem 'factory_bot_rails', '~> 4.11'
  gem 'ffaker', '~> 2.10'
  gem 'i18n-tasks', '~> 0.9.24'
  gem 'rspec-rails', '~> 3.7'
  gem 'selenium-webdriver', '~> 3.14'
  gem 'sqlite3'
  gem 'webmock', '~> 3.4'
end
group :production do
  gem 'pg'
  gem 'rails_12factor', '~> 0.0'
end
