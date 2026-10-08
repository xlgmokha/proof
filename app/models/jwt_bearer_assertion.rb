# frozen_string_literal: true

# Validates a JWT used as an authorization grant (RFC 7523 Section 3).
#
# The assertion must be issued by the authenticated client (iss), be signed with
# a key the client registered (jwks or jwks_uri), be addressed to this server
# (aud), carry an expiration time, and may only be redeemed once.
class JwtBearerAssertion
  class Invalid < StandardError; end

  ALGORITHMS = %w[RS256 RS384 RS512 PS256 PS384 PS512 ES256 ES384 ES512].freeze
  LEEWAY = 1.minute
  MAX_LIFETIME = 1.hour
  MAX_JTI_LENGTH = 255

  # The unverified `iss` of an assertion, used to find the key to verify it with.
  def self.issuer_of(assertion)
    JWT.decode(assertion.to_s, nil, false)[0]['iss']
  rescue JWT::DecodeError
    nil
  end

  def initialize(client, audiences:, sole_audience: false)
    @client = client
    @audiences = Array(audiences)
    @sole_audience = sole_audience
  end

  # Returns the verified claims of the assertion or raises Invalid. The
  # assertion is not consumed: call redeem! once the grant it is used for has
  # been fully validated, so a request that fails for another reason does not
  # burn an assertion the client could present again.
  def verify!(assertion)
    raise Invalid.new('assertion is missing') if assertion.blank?

    claims = decode(assertion)
    ensure_lifetime!(claims)
    ensure_identifier!(claims)
    claims
  rescue JWT::DecodeError, JwksFetcher::Error => error
    raise Invalid.new(error.message)
  end

  # Marks the assertion as used (RFC 7523 Section 3: it must not be replayed).
  def redeem!(claims)
    expires_at = Time.zone.at(claims[:exp].to_i) + LEEWAY
    return if UsedAssertion.redeem!(client, claims[:jti].to_s, expires_at)

    raise Invalid.new('assertion has already been used')
  end

  private

  attr_reader :client, :audiences, :sole_audience

  def decode(assertion)
    header = JWT.decode(assertion, nil, false)[1]
    algorithm = header['alg']
    raise Invalid.new('unsupported algorithm') unless ALGORITHMS.include?(algorithm)

    last_error = Invalid.new('no matching key')
    candidate_keys(header['kid']).each do |key|
      return decode_with(assertion, key, algorithm)
    rescue JWT::VerificationError, JWT::IncorrectAlgorithm => error
      last_error = error
    end
    raise last_error
  end

  def decode_with(assertion, key, algorithm)
    options = {
      algorithm: algorithm,
      iss: client.to_param, verify_iss: true,
      aud: audiences, verify_aud: true,
      required_claims: %w[iss sub aud exp jti],
      exp_leeway: LEEWAY.to_i, nbf_leeway: LEEWAY.to_i
    }
    claims = JWT.decode(assertion, key.verify_key, true, options)[0].with_indifferent_access
    # RFC 7523bis Section 3.2: for client authentication the issuer identifier
    # is the only audience.
    raise Invalid.new('aud must be only the issuer identifier') if sole_audience && Array(claims[:aud]) != audiences

    claims
  end

  def candidate_keys(kid)
    keys = client.jwk_set.keys
    keys = keys.select { |x| x[:kid] == kid } if kid.present?
    keys.select { |x| x[:use].blank? || x[:use] == 'sig' }
  end

  def ensure_lifetime!(claims)
    return if claims[:exp].to_i <= (Time.current + MAX_LIFETIME + LEEWAY).to_i

    raise Invalid.new('assertion lifetime is too long')
  end

  def ensure_identifier!(claims)
    jti = claims[:jti].to_s
    raise Invalid.new('jti is required') if jti.blank?
    raise Invalid.new('jti is too long') if jti.length > MAX_JTI_LENGTH
  end
end
