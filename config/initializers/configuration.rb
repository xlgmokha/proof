# frozen_string_literal: true

config = Rails.application.config
config.generators do |g|
  g.orm :active_record, primary_key_type: :uuid
end
if ENV['JWT_PRIVATE_KEY'].present?
  config.x.jwt.private_key = OpenSSL::PKey::RSA.new(ENV['JWT_PRIVATE_KEY'])
else
  config.x.jwt.private_key = OpenSSL::PKey::RSA.new(4096)
end

I18n.available_locales = [:en, :es, :fr, :ja, :ko]
I18n.default_locale = :en
