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
    client_id response_type redirect_uri scope resource state code_challenge code_challenge_method dpop_jkt authorization_details
    acr_values max_age
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

        raw[:request_uri].to_s.start_with?(PushedAuthorizationRequest::URN) ? pushed(client, raw[:request_uri]) : referenced(client, raw[:request_uri], audiences)
      elsif raw[:request].present?
        signed(client, raw[:request], audiences, pushing: pushing)
      else
        raise Invalid.new('invalid_request', 'The request must be pushed.') if client.require_pushed_authorization_requests? && !pushing
        raise Invalid.new('invalid_request', 'The request must be signed.') if client.require_signed_request_object?

        raw.slice(*PARAMETERS)
      end
    new(client, parameters)
  end

  # RFC 9101 Section 6.2: a request object the client hosts. Only URLs it
  # registered are fetched (Section 10.4).
  def self.referenced(client, request_uri, audiences)
    raise Invalid.new('invalid_request_uri', 'The request_uri is not registered.') unless client.request_uris.include?(request_uri.to_s)
    raise Invalid.new('invalid_request', 'The request must be pushed.') if client.require_pushed_authorization_requests?

    jwt = JwksFetcher.new.fetch_text(request_uri.to_s).strip
    signed(client, jwt, audiences, pushing: false)
  rescue JwksFetcher::Error => error
    raise Invalid.new('invalid_request_uri', error.message)
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
    # OAuth 2.1 Section 3.1: a parameter sent without a value is treated as omitted.
    @parameters = parameters.to_h.with_indifferent_access.reject { |_, v| v == '' }.merge(client_id: client.to_param)
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
    response_type_error || pkce_error || scope_error || resource_error || dpop_jkt_error || authorization_details_error || authentication_error
  end

  private

  def response_type_error
    return [:unauthorized_client, 'The client may not use the authorization code grant.'] unless client.grant_type?('authorization_code')

    value = self[:response_type]
    return [:invalid_request, 'response_type is required.'] if value.blank?
    return if client.valid_response_type?(value)

    [:unsupported_response_type, nil]
  end

  # RFC 7636 Section 4.3 (the method defaults to plain, which is not
  # accepted here).
  def pkce_error
    challenge = self[:code_challenge]
    return [:invalid_request, 'code_challenge is required.'] if challenge.blank?
    return [:invalid_request, 'code_challenge is not valid.'] unless challenge.is_a?(String)
    return [:invalid_request, 'code_challenge_method must be S256.'] unless self[:code_challenge_method] == 'S256'
    # RFC 7636 Section 4.2: the S256 challenge is a 43 character base64url digest.
    return if challenge.is_a?(String) && challenge.match?(/\A[A-Za-z0-9\-_]{43}\z/)

    [:invalid_request, 'code_challenge is not valid.']
  end

  # RFC 9470 Section 4: both are optional, `max_age` is a count of seconds.
  def authentication_error
    return [:invalid_request, 'acr_values must be a string.'] unless self[:acr_values].nil? || self[:acr_values].is_a?(String)
    return if self[:max_age].nil? || (self[:max_age].is_a?(String) && self[:max_age].match?(/\A\d{1,9}\z/))

    [:invalid_request, 'max_age must be a non-negative integer.']
  end

  # RFC 9396 Section 5
  def authorization_details_error
    AuthorizationDetails.parse(self[:authorization_details], client: client)
    nil
  rescue AuthorizationDetails::Invalid => error
    [:invalid_authorization_details, error.message]
  end

  # RFC 9449 Section 10: the base64url SHA-256 thumbprint of the key.
  def dpop_jkt_error
    value = self[:dpop_jkt]
    return if value.nil? || (value.is_a?(String) && value.match?(/\A[A-Za-z0-9\-_]{43}\z/))

    [:invalid_request, 'dpop_jkt is not valid.']
  end

  def scope_error
    return if Scopes.resolve(self[:scope], allowed: client.allowed_scopes)

    [:invalid_scope, 'The requested scope is not supported.']
  end

  def resource_error
    value = self[:resource]
    return if value.blank?
    return [:invalid_target, 'Only one resource may be requested.'] unless value.is_a?(String)
    return [:invalid_target, 'resource must be an absolute URI without a fragment.'] unless ResourceIndicator.valid?(value)
    return if ResourceIndicator.permitted?(client, value)

    [:invalid_target, 'The client may not request this resource.']
  end
end
