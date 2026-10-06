# frozen_string_literal: true

# RFC 6750: protecting a resource with bearer access tokens, and RFC 9449
# Section 7 for tokens that are bound to a DPoP key.
module BearerAuthentication
  extend ActiveSupport::Concern

  REALM = 'oauth'
  # RFC 6750 Section 2.1: credentials = "Bearer" 1*SP b64token
  HEADER = /\A(Bearer|DPoP) +([A-Za-z0-9\-._~+\/]+=*)\z/i

  private

  # Sets @access_token when the request carries a usable access token, and
  # otherwise responds with the challenge described in RFC 6750 Section 3.
  def authenticate_bearer!(scope: nil)
    presented = presented_credentials
    return challenge(nil, status: :unauthorized, schemes: %w[Bearer DPoP]) if presented.empty?
    return challenge('invalid_request', 'Multiple access tokens were presented.', status: :bad_request) if presented.many?

    scheme, jwt = presented.first
    @access_token = Token.authenticate(jwt, allow_bound: true)
    return challenge('invalid_token', 'The access token is invalid.', status: :unauthorized, schemes: [scheme]) unless @access_token
    return unless certificate_constraint_satisfied?(scheme)
    return unless sender_constraint_satisfied?(scheme, jwt)
    return if scope.nil? || @access_token.scopes.include?(scope)

    challenge('insufficient_scope', 'The access token lacks the required scope.', status: :forbidden, scope: scope, schemes: [scheme])
  end

  # RFC 8705 Section 3: a token bound to a certificate is only good over a
  # connection that used it.
  def certificate_constraint_satisfied?(scheme)
    return true if @access_token.x5t_s256.blank?

    presented = ClientCertificate.from(request)
    return true if presented && ActiveSupport::SecurityUtils.secure_compare(presented.thumbprint, @access_token.x5t_s256)

    challenge('invalid_token', 'The access token is bound to a different client certificate.', status: :unauthorized, schemes: [scheme])
    false
  end

  # RFC 9449 Section 7.1: a bound token is only good with a proof from its
  # key, and a proof is only meaningful for a bound token.
  def sender_constraint_satisfied?(scheme, jwt)
    bound = @access_token.dpop_jkt.present?
    if bound != scheme.casecmp?('DPoP')
      challenge('invalid_token', 'The access token is not valid for this authentication scheme.', status: :unauthorized, schemes: [scheme])
      return false
    end
    return true unless bound

    proof = DpopProof.new(
      request.headers['DPoP'], method: request.method, url: "#{request.base_url}#{request.path}",
      access_token: jwt, nonce_required: DpopNonce.required?
    )
    return true if proof.verify! == @access_token.dpop_jkt

    challenge('invalid_token', 'The DPoP proof was not made with the key the token is bound to.', status: :unauthorized, schemes: ['DPoP'])
    false
  rescue DpopProof::UseNonce => error
    response.headers['DPoP-Nonce'] = DpopNonce.current
    challenge('use_dpop_nonce', error.message, status: :unauthorized, schemes: ['DPoP'])
    false
  rescue DpopProof::Invalid => error
    challenge('invalid_dpop_proof', error.message, status: :unauthorized, schemes: ['DPoP'])
    false
  end

  # Section 2.1 (header) and Section 2.2 (form-encoded body parameter).
  def presented_credentials
    credentials = []
    match = request.authorization.to_s.match(HEADER)
    credentials << [match[1].capitalize.sub('Dpop', 'DPoP'), match[2]] if match
    credentials << ['Bearer', request.request_parameters['access_token']] if form_encoded_body? && request.request_parameters['access_token'].present?
    credentials
  end

  def presented_bearer_tokens
    presented_credentials.map(&:last)
  end

  def form_encoded_body?
    request.post? && request.media_type == 'application/x-www-form-urlencoded'
  end

  def challenge(error, description = nil, status:, scope: nil, schemes: %w[Bearer])
    response.headers['WWW-Authenticate'] = schemes.map { |x| challenge_for(x, error, description, scope) }.join(', ')
    head status
  end

  # RFC 9728 Section 5.1: the metadata of the resource being accessed.
  def resource_metadata_url_for_request
    path = Oauth::Issuer::RESOURCES.keys.reject(&:empty?).find { |x| request.path == x || request.path.start_with?("#{x}/") }
    "#{Oauth::Issuer.identifier}/.well-known/oauth-protected-resource#{path}"
  end

  def challenge_for(scheme, error, description, scope)
    # RFC 9728 Section 5.1: point the client at the resource's metadata.
    attributes = {
      realm: REALM, error: error, error_description: description, scope: scope,
      resource_metadata: resource_metadata_url_for_request
    }
    attributes[:algs] = DpopProof::ALGORITHMS.join(' ') if scheme == 'DPoP'
    "#{scheme} #{attributes.compact.map { |k, v| %(#{k}="#{v.to_s.gsub(/[^\x20\x21\x23-\x5B\x5D-\x7E]/, '')}") }.join(', ')}"
  end
end
