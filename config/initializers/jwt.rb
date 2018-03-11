# frozen_string_literal: true

Rails.application.config.x.jwt.private_key = OpenSSL::PKey::RSA.new(2048)
