# frozen_string_literal: true

# RFC 8693: exchanging a token this server issued for a new access token, with
# a narrower scope or for another audience, optionally on behalf of an actor
# (delegation).
class TokenExchange
  GRANT_TYPE = 'urn:ietf:params:oauth:grant-type:token-exchange'
  ACCESS_TOKEN_TYPE = 'urn:ietf:params:oauth:token-type:access_token'
  REFRESH_TOKEN_TYPE = 'urn:ietf:params:oauth:token-type:refresh_token'
  JWT_TYPE = 'urn:ietf:params:oauth:token-type:jwt'
  TOKEN_TYPES = {
    ACCESS_TOKEN_TYPE => :access,
    JWT_TYPE => :access,
    REFRESH_TOKEN_TYPE => :refresh
  }.freeze

  class Invalid < StandardError
    attr_reader :error

    def initialize(error, description)
      super(description)
      @error = error
    end
  end

  def initialize(client, subject_token:, subject_token_type:, actor_token: nil, actor_token_type: nil,
                 requested_token_type: nil, scope: nil, audience: nil, resource: nil, dpop_jkt: nil)
    @client = client
    @subject_token = subject_token
    @subject_token_type = subject_token_type
    @actor_token = actor_token
    @actor_token_type = actor_token_type
    @requested_token_type = requested_token_type
    @scope = scope
    @audience = audience
    @resource = resource
    @dpop_jkt = dpop_jkt
  end

  # The new access token.
  def call
    ensure_requested_token_type!
    subject = presented(subject_token, subject_token_type, 'subject_token')
    actor = actor_token.present? ? presented(actor_token, actor_token_type, 'actor_token') : nil
    raise Invalid.new('invalid_request', 'actor_token_type requires an actor_token.') if actor.nil? && actor_token_type.present?

    Token.create!(
      subject: subject.subject, audience: client, token_type: :access,
      scope: narrowed_scope(subject), resource: target(subject), dpop_jkt: subject.dpop_jkt, authorization_details: subject.authorization_details,
      acr: subject.acr, auth_time: subject.auth_time,
      act: delegation(subject, actor), family_id: subject.family_id,
      # The new token does not outlive the one it came from.
      expired_at: [1.hour.from_now, subject.expired_at].min
    )
  end

  private

  attr_reader :client, :subject_token, :subject_token_type, :actor_token, :actor_token_type,
    :requested_token_type, :scope, :audience, :resource, :dpop_jkt

  # Section 2.1: only access tokens are issued.
  def ensure_requested_token_type!
    return if requested_token_type.blank? || requested_token_type == ACCESS_TOKEN_TYPE

    raise Invalid.new('invalid_request', 'requested_token_type is not supported.')
  end

  # A token this server issued to the calling client, that is still usable.
  def presented(jwt, type, name)
    raise Invalid.new('invalid_request', "#{name} is required.") if jwt.blank?
    raise Invalid.new('invalid_request', "#{name}_type is required.") if type.blank?
    raise Invalid.new('invalid_request', "#{name}_type is not supported.") unless TOKEN_TYPES.key?(type)

    token = Token.from_jwt(jwt, token_type: TOKEN_TYPES.fetch(type))
    if token&.issued_to?(client) && !token.revoked? && !token.expired?
      ensure_possession!(token, name)
      return token
    end

    # Section 2.2.2: any unacceptable subject or actor token is invalid_request.
    raise Invalid.new('invalid_request', "The #{name} is not valid.")
  end

  # RFC 9449 Section 8: a bound token is only good with a proof from its key.
  def ensure_possession!(token, name)
    return if token.dpop_jkt.blank? || token.dpop_jkt == dpop_jkt

    raise Invalid.new('invalid_dpop_proof', "The #{name} is bound to a different key.")
  end

  # Section 2.1: the target may not widen what the subject token was limited to.
  def target(subject)
    return subject.resource if resource.blank? && audience.blank?
    raise Invalid.new('invalid_target', 'audience must be a string.') unless audience.is_a?(String) || audience.nil?

    requested = resource.presence || audience
    raise Invalid.new('invalid_target', 'The client may not request this target.') unless ResourceIndicator.permitted?(client, requested) || requested == subject.resource
    raise Invalid.new('invalid_target', 'The target exceeds that of the subject_token.') if subject.resource.present? && requested != subject.resource

    requested
  end

  def narrowed_scope(subject)
    return subject.scope if scope.blank?

    requested = Scopes.parse(scope).uniq
    raise Invalid.new('invalid_scope', 'The scope exceeds that of the subject_token.') unless Scopes.subset?(requested, subject.scopes)

    Scopes.format(requested)
  end

  # Section 4.1: the actor goes outermost, with earlier actors nested in it.
  def delegation(subject, actor)
    return subject.act if actor.nil?

    { sub: actor.subject.to_param }.merge(subject.act.present? ? { act: subject.act } : {})
  end
end
