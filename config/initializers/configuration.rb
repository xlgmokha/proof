# frozen_string_literal: true

config = Rails.application.config
config.generators do |g|
  g.orm :active_record, primary_key_type: :uuid
end
config.x.jwt.private_key = OpenSSL::PKey::RSA.new(2048)

I18n.available_locales = [:en, :es, :fr, :ja, :ko]
I18n.default_locale = :en
