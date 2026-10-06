# frozen_string_literal: true

# RFC 6750: protecting a resource with bearer access tokens.
module BearerAuthentication
  extend ActiveSupport::Concern

  REALM = 'oauth'
  # RFC 6750 Section 2.1: credentials = "Bearer" 1*SP b64token
  HEADER = /\ABearer +([A-Za-z0-9\-._~+\/]+=*)\z/i

  private

  # Sets @access_token when the request carries a usable access token, and
  # otherwise responds with the challenge described in RFC 6750 Section 3.
  def authenticate_bearer!(scope: nil)
    presented = presented_bearer_tokens
    return bearer_challenge(nil, status: :unauthorized) if presented.empty?
    return bearer_challenge('invalid_request', 'Multiple access tokens were presented.', status: :bad_request) if presented.many?

    @access_token = Token.authenticate(presented.first)
    return bearer_challenge('invalid_token', 'The access token is invalid.', status: :unauthorized) unless @access_token
    return if scope.nil? || @access_token.scopes.include?(scope)

    bearer_challenge('insufficient_scope', 'The access token lacks the required scope.', status: :forbidden, scope: scope)
  end

  # Section 2.1 (header) and Section 2.2 (form-encoded body parameter).
  def presented_bearer_tokens
    tokens = []
    header = request.authorization.to_s
    tokens << header[HEADER, 1] if header.match?(/\ABearer\b/i)
    tokens << request.request_parameters['access_token'] if form_encoded_body? && request.request_parameters['access_token'].present?
    tokens.compact
  end

  def form_encoded_body?
    request.post? && request.media_type == 'application/x-www-form-urlencoded'
  end

  def bearer_challenge(error, description = nil, status:, scope: nil)
    attributes = { realm: REALM, error: error, error_description: description, scope: scope }
    challenge = attributes.compact.map { |k, v| %(#{k}="#{v.to_s.gsub('"', '')}") }.join(', ')
    response.headers['WWW-Authenticate'] = "Bearer #{challenge}"
    head status
  end
end
