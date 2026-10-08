# frozen_string_literal: true

# A signed authorization request (RFC 9101): the request parameters are the
# claims of a JWT signed with a key the client registered.
class RequestObject
  class Invalid < StandardError; end

  ALGORITHMS = JwtBearerAssertion::ALGORITHMS
  TYP = 'oauth-authz-req+jwt' # Section 10.8
  LEEWAY = 1.minute
  MAX_LIFETIME = 1.hour
  # Claims that describe the JWT rather than the request.
  RESERVED = %w[iss aud exp nbf iat jti].freeze

  def initialize(client, audiences:)
    @client = client
    @audiences = Array(audiences)
  end

  # The request parameters carried by the object, or raises Invalid.
  def parameters_from(jwt)
    claims = decode(jwt)
    ensure_claims!(claims)
    claims.except(*RESERVED)
  rescue JWT::DecodeError, JwksFetcher::Error => error
    raise Invalid.new(error.message)
  end

  private

  attr_reader :client, :audiences

  def decode(jwt)
    header = JWT.decode(jwt, nil, false)[1]
    raise Invalid.new('alg is not supported') unless ALGORITHMS.include?(header['alg'])
    raise Invalid.new('typ is not supported') if header['typ'].present? && header['typ'] != TYP

    keys = client.jwk_set.keys.select { |x| x[:use].blank? || x[:use] == 'sig' }
    keys = keys.select { |x| x[:kid] == header['kid'] } if header['kid'].present?
    keys.each do |key|
      return JWT.decode(jwt, key.verify_key, true, algorithm: header['alg'], exp_leeway: LEEWAY.to_i, nbf_leeway: LEEWAY.to_i)[0].with_indifferent_access
    rescue JWT::VerificationError, JWT::IncorrectAlgorithm
      next
    end
    raise Invalid.new('signature is not valid')
  end

  # Section 4 and Section 10.2: the object is for this server, from this client.
  def ensure_claims!(claims)
    raise Invalid.new('iss must be the client_id') unless claims[:iss] == client.to_param
    raise Invalid.new('aud must be the authorization server') unless (Array(claims[:aud]) & audiences).any?
    raise Invalid.new('exp is required') if claims[:exp].blank?
    raise Invalid.new('lifetime is too long') if claims[:exp].to_i > (Time.current + MAX_LIFETIME + LEEWAY).to_i
    raise Invalid.new('client_id must match') if claims[:client_id].present? && claims[:client_id] != client.to_param
    raise Invalid.new('request and request_uri must not be nested') if claims.key?(:request) || claims.key?(:request_uri)
  end
end
