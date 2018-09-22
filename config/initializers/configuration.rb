# frozen_string_literal: true

config = Rails.application.config
config.x.jwt.private_key = OpenSSL::PKey::RSA.new(2048)

I18n.available_locales = [:en, :es, :fr, :ja, :ko]
I18n.default_locale = :en
