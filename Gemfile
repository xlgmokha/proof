# frozen_string_literal: true

source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }
ruby '2.6.0'

gem 'activerecord-session_store', '~> 1.1'
gem 'audited', '~> 4.8'
gem 'bcrypt', '~> 3.1'
gem 'bootsnap', '>= 1.1.0', require: false
gem 'dotenv', '~> 2.5'
gem 'email_validator', '~> 1.6'
gem 'flipper', '~> 0.16'
gem 'flipper-active_record', '~> 0.16'
gem 'jbuilder', '~> 2.5'
gem 'jwt', '~> 2.1'
gem 'local_time', '~> 2.1'
gem 'pg'
gem 'puma', '~> 3.11'
gem 'rails', '~> 5.2.0'
gem 'rotp', '~> 3.3'
gem 'saml-kit', '~> 1.0'
gem 'scim-kit'
gem 'scim-shady', '~> 0.2'
gem 'spank', '~> 1.0'
gem 'turbolinks', '~> 5'
gem 'webpacker', '~> 3.5'
# gem 'redis', '~> 4.0'
group :doc do
  gem 'jekyll', '~> 3.8'
  gem "minima", "~> 2.0" # This is the default theme for new Jekyll sites.
end
group :development do
  gem 'brakeman', '~> 4.3'
  gem 'bundler-audit', '~> 0.6'
  gem 'erb_lint', require: false
  gem 'listen', '>= 3.0.5', '< 3.2'
  gem 'rubocop', '~> 0.59', require: false
  gem 'web-console', '>= 3.3.0'
end
group :development, :test do
  gem 'byebug', platforms: [:mri, :mingw, :x64_mingw]
  gem 'i18n-tasks', '~> 0.9.24'
  gem 'rspec-rails', '~> 3.8'
  gem 'vcr', '~> 4.0'
end
group :test do
  gem 'capybara', '~> 3.6'
  gem 'capybara-screenshot', '~> 1.0'
  gem 'factory_bot_rails', '~> 4.11'
  gem 'ffaker', '~> 2.10'
  gem 'rubocop-rspec', '~> 1.30'
  gem 'selenium-webdriver', '~> 3.14'
  gem 'webmock', '~> 3.4'
end
group :production do
  gem 'rails_12factor', '~> 0.0'
end
