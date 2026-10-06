# frozen_string_literal: true

class Client < ApplicationRecord
  RESPONSE_TYPES = %w[code].freeze
  # RFC 8252 Section 7.1: a private-use scheme is a reverse domain name, with a path.
  PRIVATE_USE_SCHEME = %r{\A[a-z][a-z0-9+\-]*(\.[a-z0-9+\-]+)+:/[^#\s]*\z}i
  LOOPBACK_HOSTS = %w[127.0.0.1 [::1]].freeze
  GRANT_TYPES = GrantTypes::ALL
  audited
  has_secure_password
  has_many :authorizations, dependent: :delete_all
  has_many :pushed_authorization_requests, dependent: :delete_all
  has_many :device_authorizations, dependent: :delete_all
  before_destroy :delete_tokens
  attribute :redirect_uris, :string, array: true
  enum :token_endpoint_auth_method, {
    client_secret_basic: 0,
    client_secret_post: 1,
    client_secret_none: 2,
    private_key_jwt: 3,
    tls_client_auth: 4,
    self_signed_tls_client_auth: 5,
  }, validate: true

  validates :redirect_uris, presence: true, if: -> { grant_types.include?('authorization_code') }
  validates :client_uri, :tos_uri, :policy_uri, format: { with: URI_REGEX }, allow_blank: true
  validate :grant_and_response_types_are_supported
  validate :scope_is_supported
  validates :jwks_uri, format: { with: URI_REGEX }, allow_blank: true
  validate :request_uris_are_https
  validate :tls_client_auth_is_identified
  validates :logo_uri, format: { with: URI_REGEX }, allow_blank: true
  validates :name, presence: true
  validate :jwks_uri_and_jwks_are_exclusive
  validates :jwks, jwks: true
  validates_each :redirect_uris do |record, _attr, value|
    invalid_uri = Array(value).find { |x| !x.match?(URI_REGEX) && !x.match?(PRIVATE_USE_SCHEME) }
    record.errors.add(:redirect_uris, 'is invalid.') if invalid_uri
    # RFC 6749 Section 3.1.2: the redirect endpoint must not have a fragment.
    record.errors.add(:redirect_uris, 'must not include a fragment.') if Array(value).any? { |x| x.include?('#') }
    # RFC 9700 Section 2.1: plain http is only for loopback redirects (RFC 8252 Section 7.3).
    insecure = Array(value).any? do |x|
      uri = URI.parse(x)
      uri.scheme == 'http' && !(LOOPBACK_HOSTS + %w[localhost]).include?(uri.host)
    rescue URI::InvalidURIError
      false
    end
    record.errors.add(:redirect_uris, 'must use https unless they are loopback addresses.') if insecure
  end

  after_initialize do
    self.password = SecureRandom.base58(32) unless password_digest
  end

  def grant_type?(grant_type)
    grant_types.include?(grant_type)
  end

  # RFC 7591 Section 2: the scopes the client may request.
  def allowed_scopes
    scope.present? ? Scopes.parse(scope) : Scopes::SUPPORTED
  end

  # RFC 7591 Section 2: the client's public keys, by value or by reference.
  def jwk_set
    JwksFetcher.new.key_set_for(self)
  end

  # Public clients cannot keep a secret (RFC 6749 Section 2.1).
  def public_client?
    client_secret_none?
  end

  def access_token(scope: Scopes.format(Scopes::DEFAULT), resource: nil, authorization_details: nil, expired_at: nil)
    Token.create!(
      subject: self, audience: self, token_type: :access, scope: scope, resource: resource,
      authorization_details: authorization_details, expired_at: expired_at
    )
  end

  def revoke(token)
    token.revoke! if token.issued_to?(self)
  end

  # RFC 6749 Section 3.1.2.3: the redirect_uri may only be omitted when a single
  # one is registered. Registered URIs are compared exactly (RFC 9700
  # Section 4.1.3), except for the port of a loopback redirect (RFC 8252
  # Section 7.3). Returns nil when the request's value is not acceptable.
  def resolve_redirect_uri(redirect_uri)
    return redirect_uris.first if redirect_uri.blank? && redirect_uris.one?
    return if redirect_uri.blank?

    redirect_uri if valid_redirect_uri?(redirect_uri)
  end

  def valid_redirect_uri?(redirect_uri)
    return false if redirect_uri.blank?

    redirect_uris.include?(redirect_uri) || loopback_match?(redirect_uri)
  end

  def valid_response_type?(response_type)
    RESPONSE_TYPES.include?(response_type)
  end

  # Creates the authorization for an approved request and returns the URL to
  # send the user agent to.
  def redirect_url_for(user, oauth, authentication: {})
    authorization = authorizations.create!(
      user: user,
      challenge: oauth[:code_challenge],
      challenge_method: :sha256,
      redirect_uri: oauth[:redirect_uri].presence,
      scope: Scopes.format(Scopes.resolve(oauth[:scope], allowed: allowed_scopes)),
      resource: oauth[:resource].presence,
      dpop_jkt: oauth[:dpop_jkt].presence,
      acr: authentication[:acr], auth_time: authentication[:auth_time],
      authorization_details: AuthorizationDetails.parse(oauth[:authorization_details], client: self)
    )
    redirect_url(
      code: authorization.code, state: oauth[:state], iss: Oauth::Issuer.identifier,
      to: oauth[:redirect_uri].presence
    )
  end

  # RFC 6749 Section 4.1.2: the response parameters are added to the query
  # component of the redirect URI.
  def redirect_url(to: nil, **parameters)
    redirect_uri = resolve_redirect_uri(to)
    return unless redirect_uri

    uri = URI.parse(redirect_uri)
    query = URI.decode_www_form(uri.query.to_s)
    parameters.each { |key, value| query << [key.to_s, value.to_s] unless value.nil? || value == '' }
    uri.query = URI.encode_www_form(query)
    uri.to_s
  end

  private

  # RFC 7591 Section 2.1: the grant types and response types a client uses
  # must go together, and a client that cannot keep a secret cannot use
  # client credentials.
  def grant_and_response_types_are_supported
    errors.add(:grant_types, 'are not supported.') unless (grant_types - GRANT_TYPES).empty?
    errors.add(:response_types, 'are not supported.') unless (response_types - RESPONSE_TYPES).empty?
    errors.add(:grant_types, 'must include authorization_code to use the code response type.') if
      response_types.include?('code') && !grant_types.include?('authorization_code')
    errors.add(:response_types, 'must include code to use the authorization_code grant type.') if
      grant_types.include?('authorization_code') && !response_types.include?('code')
    errors.add(:grant_types, 'must not include client_credentials for a public client.') if
      public_client? && grant_types.include?('client_credentials')
  end

  def scope_is_supported
    return if scope.blank?

    errors.add(:scope, 'is not supported.') unless Scopes.valid?(Scopes.parse(scope))
  end

  def loopback_match?(candidate)
    uri = URI.parse(candidate)
    return false unless uri.scheme == 'http' && LOOPBACK_HOSTS.include?(uri.host)

    redirect_uris.any? do |registered|
      other = URI.parse(registered)
      other.scheme == 'http' && other.host == uri.host && other.path == uri.path && other.query == uri.query &&
        uri.fragment.nil? && uri.userinfo.nil?
    end
  rescue URI::InvalidURIError
    false
  end

  # RFC 8705 Section 2.1.2: exactly one way to tell which certificate is the
  # client's; Section 2.2: a self-signed certificate is matched to a key.
  def tls_client_auth_is_identified
    if tls_client_auth?
      identifiers = [tls_client_auth_subject_dn, tls_client_auth_san_dns, tls_client_auth_san_uri, tls_client_auth_san_ip, tls_client_auth_san_email]
      errors.add(:base, 'Exactly one tls_client_auth_* identifier is required.') unless identifiers.compact_blank.one?
    elsif self_signed_tls_client_auth? && jwks.blank? && jwks_uri.blank?
      errors.add(:base, 'jwks or jwks_uri is required.')
    end
  end

  def request_uris_are_https
    return if request_uris.all? { |x| x.start_with?('https://') && x.exclude?('#') }

    errors.add(:request_uris, 'must be https URLs without a fragment.')
  end

  def jwks_uri_and_jwks_are_exclusive
    return if jwks.blank? || jwks_uri.blank?

    errors.add(:jwks, 'must not be specified together with jwks_uri')
  end

  def delete_tokens
    Token.where(subject: self).or(Token.where(audience: self)).delete_all
  end
end
