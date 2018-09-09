# frozen_string_literal: true

config = Rails.application.config
config.x.jwt.private_key = OpenSSL::PKey::RSA.new(2048)
