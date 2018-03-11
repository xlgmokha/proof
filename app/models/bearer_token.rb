# frozen_string_literal: true

class BearerToken
  def initialize(private_key = Rails.application.config.x.jwt.private_key)
    @private_key = private_key
    @public_key = private_key.public_key
  end

  def encode(payload)
    JWT.encode(defaults.merge(payload), private_key, 'RS256')
  end

  def decode(token)
    decoded = JWT.decode(token, public_key, true, algorithm: 'RS256')[0]
    decoded.with_indifferent_access
  rescue StandardError
    {}
  end

  private

  attr_reader :private_key, :public_key

  def defaults
    issued_at = Time.current.to_i
    {
      exp: 1.hour.from_now,
      iat: issued_at,
      iss: Saml::Kit.configuration.entity_id,
      nbf: issued_at,
    }
  end
end
