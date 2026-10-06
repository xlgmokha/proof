# frozen_string_literal: true

# Builds DPoP proofs (RFC 9449 Section 4.2) for specs.
module DpopHelpers
  def dpop_key
    @dpop_key ||= OpenSSL::PKey::EC.generate('prime256v1')
  end

  def dpop_thumbprint(key = dpop_key)
    JWT::JWK::Thumbprint.new(JWT::JWK.new(key)).generate
  end

  def dpop_proof(url:, method: 'POST', key: dpop_key, access_token: nil, header: {}, claims: {})
    payload = { jti: SecureRandom.uuid, htm: method, htu: url, iat: Time.current.to_i }
    payload[:ath] = Base64.urlsafe_encode64(Digest::SHA256.digest(access_token), padding: false) if access_token
    JWT.encode(
      payload.merge(claims), key, 'ES256',
      { typ: 'dpop+jwt', jwk: JWT::JWK.new(key).export.except(:kid) }.merge(header)
    )
  end
end

RSpec.configure { |config| config.include DpopHelpers }
