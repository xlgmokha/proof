# frozen_string_literal: true

# Client authentication at the token, introspection and revocation endpoints
# (RFC 6749 Section 2.3, RFC 7523 Section 2.2).
module ClientAuthentication
  extend ActiveSupport::Concern

  CLIENT_ASSERTION_TYPE = 'urn:ietf:params:oauth:client-assertion-type:jwt-bearer'

  included do
    before_action :ensure_form_parameters!
  end

  private

  attr_reader :current_client

  # RFC 6749 Section 3.2 and Appendix B: parameters are sent in a
  # form-urlencoded body, and none may be repeated.
  def ensure_form_parameters!
    return if request.query_parameters.blank? && !repeated_form_parameters? && form_content?

    # RFC 8707 and RFC 8693 allow these to repeat; only one target is supported here.
    if request.query_parameters.blank? && form_content? && (repeated_keys - %w[resource audience]).empty? && repeated_keys.any?
      response.headers['Cache-Control'] = 'no-store'
      response.headers['Pragma'] = 'no-cache'
      return render_oauth_error GrantError.new('invalid_target', 'Only one resource or audience may be requested.')
    end

    response.headers['Cache-Control'] = 'no-store'
    response.headers['Pragma'] = 'no-cache'
    render_oauth_error GrantError.new('invalid_request', 'Parameters must be sent once, in a form-urlencoded request body.')
  end

  def form_content?
    request.raw_post.blank? || request.media_type == 'application/x-www-form-urlencoded'
  end

  def repeated_form_parameters?
    repeated_keys.any?
  rescue ArgumentError
    true
  end

  def repeated_keys
    keys = URI.decode_www_form(request.raw_post.to_s).map(&:first).reject { |x| x.end_with?('[]') }
    keys.tally.select { |_, count| count > 1 }.keys
  end

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

    authenticate_mtls || authenticate_public
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
    return spend_time(secret) unless client && (client.client_secret_basic? || client.client_secret_post?)

    client.authenticate(secret)
  end

  def authenticate_post_body
    client = Client.find_by(id: params[:client_id])
    return spend_time(params[:client_secret]) unless client&.client_secret_post? || client&.client_secret_basic?

    client.authenticate(params[:client_secret].to_s)
  end

  # RFC 7523 Section 2.2: the client proves possession of a registered key.
  def authenticate_assertion
    return unless params[:client_assertion_type] == CLIENT_ASSERTION_TYPE

    client = Client.find_by(id: JwtBearerAssertion.issuer_of(params[:client_assertion]))
    return unless client&.private_key_jwt?
    return if params[:client_id].present? && params[:client_id] != client.to_param

    assertion = JwtBearerAssertion.new(client, audiences: [Oauth::Issuer.identifier], sole_audience: true)
    claims = assertion.verify!(params[:client_assertion])
    return unless claims[:sub].to_s == client.to_param

    assertion.redeem!(claims)
    client
  rescue JwtBearerAssertion::Invalid => error
    logger.info(error)
    nil
  end

  attr_reader :client_certificate

  DUMMY_DIGEST = BCrypt::Password.create('not a secret', cost: BCrypt::Engine.cost)

  # A secret is checked even when the client is not known, so the time taken
  # does not show which client ids exist.
  def spend_time(secret)
    DUMMY_DIGEST.is_password?(secret.to_s)
    nil
  end

  # RFC 8705 Section 2: the client is identified by its client_id and proves
  # itself with the certificate of the TLS connection.
  def authenticate_mtls
    @client_certificate = ClientCertificate.from(request)
    return unless @client_certificate && params[:client_id].present?

    client = Client.find_by(id: params[:client_id])
    return unless client
    return client if client.tls_client_auth? && @client_certificate.matches?(client)

    client if client.self_signed_tls_client_auth? && @client_certificate.key_of?(client)
  end

  # RFC 6749 Section 2.1: public clients are identified by their client_id alone.
  def authenticate_public
    client = Client.find_by(id: params[:client_id]) if params[:client_id].present?
    client if client&.public_client?
  end

  def assertion_audiences
    # RFC 7523bis Section 3: the issuer identifier or the token endpoint URL.
    [oauth_tokens_url, Oauth::Issuer.identifier].uniq
  end

  def render_oauth_error(error)
    body = { error: error.error, error_description: error.description }.compact
    render json: body, status: error.status
  end
end
