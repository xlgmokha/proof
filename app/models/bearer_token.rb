# frozen_string_literal: true

class BearerToken
  def initialize(private_key = Rails.application.config.x.jwt.private_key)
    @private_key = private_key
    @public_key = private_key.public_key
  end

  def encode(payload, typ: nil)
    header = { kid: jwk.kid }
    header[:typ] = typ if typ
    JWT.encode(defaults.merge(payload), private_key, 'RS256', header)
  end

  def jwk
    @jwk ||= JWT::JWK.new(public_key, { use: 'sig', alg: 'RS256' })
  end

  # When a typ is given the JWT must declare it (RFC 9068 Section 4), so one
  # kind of token cannot be presented as another.
  def decode(token, typ: nil)
    decoded, header = JWT.decode(
      token, public_key, true, algorithm: 'RS256', iss: Oauth::Issuer.identifier, verify_iss: true
    )
    return {} if typ && header['typ'] != typ

    decoded.with_indifferent_access
  rescue StandardError => error
    Rails.logger.error(error)
    {}
  end

  private

  attr_reader :private_key, :public_key

  def defaults
    issued_at = Time.current.to_i
    {
      exp: 1.hour.from_now.to_i,
      iat: issued_at,
      iss: Oauth::Issuer.identifier,
      nbf: issued_at,
    }
  end
end
