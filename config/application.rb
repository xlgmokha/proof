# frozen_string_literal: true

require_relative 'boot'

require "rails"
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_view/railtie"
require "dotenv"
Dotenv.load(".env.local", ".env.#{Rails.env}", ".env")

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Proof
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 5.2

    # Settings in config/environments/* take precedence over those specified
    # here.
    # Application configuration can go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded after loading
    # the framework and any gems in your application.
    config.middleware.delete(Rack::Runtime)
    routes.default_url_options[:host] = ENV['RAILS_HOST']
    routes.default_url_options[:protocol] = 'https' unless Rails.env.test?
  end
end
