# frozen_string_literal: true

class BearerToken
  def initialize(private_key = Rails.application.config.x.jwt.private_key)
    @private_key = private_key
    @public_key = private_key.public_key
  end

  def encode(payload)
    JWT.encode(timestamps.merge(payload), private_key, 'RS256')
  end

  def decode(token)
    decoded = JWT.decode(token, public_key, true, algorithm: 'RS256')[0]
    decoded.with_indifferent_access
  rescue StandardError
    {}
  end

  private

  attr_reader :private_key, :public_key

  def timestamps
    { exp: expiration.to_i, iat: issued_at.to_i }
  end

  def issued_at
    Time.current
  end

  def expiration
    1.hour.from_now
  end
end
