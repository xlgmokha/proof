# frozen_string_literal: true

# The parameters of an authorization request (RFC 6749 Section 4.1.1), however
# they arrived: in the query, in a signed request object (RFC 9101) or pushed
# beforehand (RFC 9126), and the checks that apply to them.
class AuthorizationRequest
  class Invalid < StandardError
    attr_reader :error, :description

    def initialize(error, description = nil)
      super(description || error)
      @error = error
      @description = description
    end
  end

  PARAMETERS = %w[
    client_id response_type redirect_uri scope resource state code_challenge code_challenge_method
  ].freeze

  attr_reader :client, :parameters

  # `raw` are the parameters of the HTTP request.
  #
  # `pushing` is set when the request is being pushed (RFC 9126 Section 2.1), as
  # opposed to being used at the authorization endpoint.
  def self.load(client, raw, audiences:, pushing: false)
    raw = raw.to_h.with_indifferent_access
    parameters =
      if raw[:request_uri].present?
        raise Invalid.new('invalid_request', 'request_uri must not be pushed.') if pushing

        pushed(client, raw[:request_uri])
      elsif raw[:request].present?
        signed(client, raw[:request], audiences, pushing: pushing)
      else
        raise Invalid.new('invalid_request', 'The request must be pushed.') if client.require_pushed_authorization_requests? && !pushing
        raise Invalid.new('invalid_request', 'The request must be signed.') if client.require_signed_request_object?

        raw.slice(*PARAMETERS)
      end
    new(client, parameters)
  end

  def self.pushed(client, request_uri)
    pushed = PushedAuthorizationRequest.consume(request_uri, client)
    raise Invalid.new('invalid_request_uri', 'The request_uri is not valid.') if pushed.nil?

    pushed.parameters.slice(*PARAMETERS)
  end

  # RFC 9101 Section 6.3: only what is inside the signed object counts.
  def self.signed(client, jwt, audiences, pushing:)
    raise Invalid.new('invalid_request', 'The request must be pushed.') if client.require_pushed_authorization_requests? && !pushing

    RequestObject.new(client, audiences: audiences).parameters_from(jwt).slice(*PARAMETERS)
  rescue RequestObject::Invalid => error
    raise Invalid.new('invalid_request_object', error.message)
  end

  def initialize(client, parameters)
    @client = client
    @parameters = parameters.to_h.with_indifferent_access.merge(client_id: client.to_param)
  end

  def [](name)
    parameters[name]
  end

  # The redirect URI that responses go to, or nil if it cannot be trusted.
  def redirect_uri
    @redirect_uri ||= client.resolve_redirect_uri(self[:redirect_uri])
  end

  # The error to report for a request whose client and redirect URI are fine.
  def error
    response_type_error || pkce_error || scope_error || resource_error
  end

  private

  def response_type_error
    return if client.valid_response_type?(self[:response_type])

    [:unsupported_response_type, nil]
  end

  # RFC 7636 Section 4.3 (the method defaults to plain, which is not
  # accepted here).
  def pkce_error
    challenge = self[:code_challenge]
    return [:invalid_request, 'code_challenge is required.'] if challenge.blank?
    return [:invalid_request, 'code_challenge_method must be S256.'] unless self[:code_challenge_method] == 'S256'
    return if Authorization::PKCE_VERIFIER.match?(challenge)

    [:invalid_request, 'code_challenge is not valid.']
  end

  def scope_error
    return if Scopes.resolve(self[:scope], allowed: client.allowed_scopes)

    [:invalid_scope, 'The requested scope is not supported.']
  end

  def resource_error
    value = self[:resource]
    return if value.blank?
    return [:invalid_target, 'Only one resource may be requested.'] unless value.is_a?(String)
    return if ResourceIndicator.valid?(value)

    [:invalid_target, 'resource must be an absolute URI without a fragment.']
  end
end
