# frozen_string_literal: true

class Tfa
  attr_reader :user

  def initialize(user)
    @user = user
  end

  def setup?
    secret.present?
  end

  def provisioning_uri
    totp = ::ROTP::TOTP.new(secret, issuer: 'saml-kit')
    totp.provisioning_uri(user.email)
  end

  def build_secret
    user.tfa_secret = ::ROTP::Base32.random_base32
  end

  def disable!
    user.update!(tfa_secret: nil)
  end

  def secret
    user.tfa_secret
  end

  def current_totp
    ROTP::TOTP.new(secret).now
  end
end
