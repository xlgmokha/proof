# frozen_string_literal: true

# Verifies a DPoP proof (RFC 9449 Section 4.3), which shows that the sender of
# a request holds the private key an access token is bound to.
class DpopProof
  class Invalid < StandardError; end

  ALGORITHMS = %w[RS256 RS384 RS512 PS256 PS384 PS512 ES256 ES384 ES512].freeze
  TYP = 'dpop+jwt'
  # How far the proof's iat may be from now (Section 11.1).
  WINDOW = 5.minutes
  PRIVATE_KEY_MEMBERS = %w[d p q dp dq qi oth k].freeze

  # `url` is the request URL; its query and fragment are ignored (htu).
  def initialize(proof, method:, url:, access_token: nil)
    @proof = proof
    @method = method
    @url = url
    @access_token = access_token
  end

  # The JWK thumbprint (RFC 7638) of the proof's key, which tokens are bound to.
  def verify!
    raise Invalid.new('A DPoP proof is required.') if proof.blank?

    header = JWT.decode(proof, nil, false)[1]
    ensure_header!(header)
    key = JWT::JWK.import(header['jwk'].transform_keys(&:to_sym))
    claims = JWT.decode(proof, key.verify_key, true, algorithm: header['alg'], verify_iat: false)[0]
    ensure_claims!(claims)
    ensure_unused!(claims)
    JWT::JWK::Thumbprint.new(key).generate
  rescue JWT::DecodeError, JWT::JWKError, KeyError, NoMethodError => error
    raise Invalid.new(error.message)
  end

  private

  attr_reader :proof, :method, :url, :access_token

  def ensure_header!(header)
    raise Invalid.new('typ must be dpop+jwt.') unless header['typ'] == TYP
    raise Invalid.new('alg is not supported.') unless ALGORITHMS.include?(header['alg'])

    jwk = header['jwk']
    raise Invalid.new('jwk is required.') unless jwk.is_a?(Hash)
    raise Invalid.new('jwk must be a public key.') if (jwk.keys.map(&:to_s) & PRIVATE_KEY_MEMBERS).any?
  end

  def ensure_claims!(claims)
    raise Invalid.new('jti is required.') if claims['jti'].blank?
    raise Invalid.new('htm does not match the request.') unless claims['htm'] == method
    raise Invalid.new('htu does not match the request.') unless normalize(claims['htu']) == normalize(url)
    raise Invalid.new('iat is outside the acceptable window.') unless fresh?(claims['iat'])
    return if access_token.nil? || claims['ath'] == self.class.hash_of(access_token)

    raise Invalid.new('ath does not match the access token.')
  end

  def fresh?(iat)
    iat.is_a?(Numeric) && (Time.current.to_i - iat.to_i).abs <= WINDOW.to_i
  end

  def ensure_unused!(claims)
    return if UsedProof.redeem!('dpop', claims['jti'], expires_at: WINDOW.from_now + WINDOW)

    raise Invalid.new('The proof was already used.')
  end

  # RFC 9449 Section 4.2: compare without the query and fragment.
  def normalize(value)
    uri = URI.parse(value.to_s)
    uri.query = nil
    uri.fragment = nil
    uri.scheme = uri.scheme&.downcase
    uri.host = uri.host&.downcase
    uri.port = nil if uri.port == uri.default_port
    # RFC 3986 Sections 6.2.2 and 6.2.3: case, dot segments, empty path.
    uri.normalize.to_s
  rescue URI::InvalidURIError
    nil
  end

  # The ath claim: base64url of the SHA-256 of the access token (Section 4.2).
  def self.hash_of(token)
    Base64.urlsafe_encode64(Digest::SHA256.digest(token), padding: false)
  end
end
