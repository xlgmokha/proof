# frozen_string_literal: true

require 'capybara/rails'
require 'capybara-screenshot/rspec'

Capybara.register_driver :selenium do |app|
  Capybara::Selenium::Driver.new(app, browser: :chrome)
end

# A headless Chrome that also works in containers (CHROME_BIN points at the binary).
Capybara.register_driver :headless_chrome do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.binary = ENV['CHROME_BIN'] if ENV['CHROME_BIN'].present?
  %w[--headless=new --no-sandbox --disable-dev-shm-usage --disable-gpu --window-size=1400,1000].each { |x| options.add_argument(x) }
  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end

RSpec.configure do |config|
  config.before(:each, type: :system) do
    driven_by :rack_test
  end

  config.before(:each, :js, type: :system) do
    driven_by ENV['HEADLESS'].present? ? :headless_chrome : :selenium
  end
end
