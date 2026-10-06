# frozen_string_literal: true

# Client authentication at the token, introspection and revocation endpoints
# (RFC 6749 Section 2.3, RFC 7523 Section 2.2).
module ClientAuthentication
  extend ActiveSupport::Concern

  CLIENT_ASSERTION_TYPE = 'urn:ietf:params:oauth:client-assertion-type:jwt-bearer'

  private

  attr_reader :current_client

  def authenticate_client!
    @current_client = identify_client
    return if @current_client

    response.headers['WWW-Authenticate'] = 'Basic realm="oauth"'
    render_oauth_error GrantError.new('invalid_client', 'Client authentication failed.', status: :unauthorized)
  rescue GrantError => error
    render_oauth_error error
  end

  # A request may use only one authentication method (RFC 6749 Section 2.3).
  def identify_client
    basic = basic_credentials
    methods = [basic.present?, params[:client_secret].present?, params[:client_assertion].present?]
    raise GrantError.new('invalid_request', 'Multiple client authentication methods were used.') if methods.count(true) > 1

    return authenticate_basic(*basic) if basic.present?
    return authenticate_assertion if params[:client_assertion].present?
    return authenticate_post_body if params[:client_secret].present?

    authenticate_public
  end

  # RFC 6749 Section 2.3.1: the id and secret are form-urlencoded before being
  # joined and Base64 encoded.
  def basic_credentials
    header = request.authorization.to_s
    return unless header.match?(/\ABasic /i)

    decoded = Base64.strict_decode64(header.split(' ', 2).last.to_s)
    id, secret = decoded.split(':', 2)
    return if secret.nil?

    [URI.decode_www_form_component(id), URI.decode_www_form_component(secret)]
  rescue ArgumentError
    nil
  end

  def authenticate_basic(id, secret)
    client = Client.find_by(id: id)
    return unless client && (client.client_secret_basic? || client.client_secret_post?)

    client.authenticate(secret)
  end

  def authenticate_post_body
    client = Client.find_by(id: params[:client_id])
    return unless client&.client_secret_post?

    client.authenticate(params[:client_secret].to_s)
  end

  # RFC 7523 Section 2.2: the client proves possession of a registered key.
  def authenticate_assertion
    return unless params[:client_assertion_type] == CLIENT_ASSERTION_TYPE

    client = Client.find_by(id: JwtBearerAssertion.issuer_of(params[:client_assertion]))
    return unless client&.private_key_jwt?
    return if params[:client_id].present? && params[:client_id] != client.to_param

    assertion = JwtBearerAssertion.new(client, audiences: assertion_audiences)
    claims = assertion.verify!(params[:client_assertion])
    return unless claims[:sub].to_s == client.to_param

    assertion.redeem!(claims)
    client
  rescue JwtBearerAssertion::Invalid => error
    logger.info(error)
    nil
  end

  # RFC 6749 Section 2.1: public clients are identified by their client_id alone.
  def authenticate_public
    client = Client.find_by(id: params[:client_id]) if params[:client_id].present?
    client if client&.public_client?
  end

  def assertion_audiences
    [oauth_tokens_url, root_url, Oauth::Issuer.identifier].uniq
  end

  def render_oauth_error(error)
    body = { error: error.error, error_description: error.description }.compact
    render json: body, status: error.status
  end
end
