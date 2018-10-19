# frozen_string_literal: true

require 'capybara/rails'
require 'capybara-screenshot/rspec'

Capybara.register_driver :selenium do |app|
  Capybara::Selenium::Driver.new(app, browser: :chrome)
end

RSpec.configure do |config|
  config.before(:each, type: :system) do
    driven_by :rack_test
  end

  config.before(:each, type: :system, js: true) do
    driven_by ENV['HEADLESS'].present? ? :selenium_chrome_headless : :selenium
  end
end
