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

  def initialize(client, audiences:, cache: Rails.cache)
    @client = client
    @audiences = Array(audiences)
    @cache = cache
  end

  # Returns the verified claims of the assertion or raises Invalid.
  def verify!(assertion)
    raise Invalid.new('assertion is missing') if assertion.blank?

    claims = decode(assertion)
    ensure_lifetime!(claims)
    ensure_unused!(claims)
    claims
  rescue JWT::DecodeError, JwksFetcher::Error => error
    raise Invalid.new(error.message)
  end

  private

  attr_reader :client, :audiences, :cache

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
      required_claims: %w[iss sub aud exp],
      exp_leeway: LEEWAY.to_i, nbf_leeway: LEEWAY.to_i
    }
    JWT.decode(assertion, key.verify_key, true, options)[0].with_indifferent_access
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

  def ensure_unused!(claims)
    return if claims[:jti].blank?

    ttl = [claims[:exp].to_i - Time.current.to_i, 0].max + LEEWAY.to_i
    fresh = cache.write("jwt-bearer:#{client.to_param}:#{claims[:jti]}", true, expires_in: ttl, unless_exist: true)
    raise Invalid.new('assertion has already been used') unless fresh
  end
end
