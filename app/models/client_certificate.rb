# frozen_string_literal: true

# The TLS client certificate of a request (RFC 8705). The TLS terminator in
# front of the application must verify the handshake and pass the certificate
# on in a header it also strips from requests that arrive from outside
# (CLIENT_CERT_HEADER, default X-Client-Cert, URL-encoded PEM as nginx's
# $ssl_client_escaped_cert), or in the SSL_CLIENT_CERT environment variable.
# Nothing is read unless MTLS_ENABLED=true.
class ClientCertificate
  def self.enabled?
    ENV['MTLS_ENABLED'] == 'true'
  end

  def self.header
    ENV.fetch('CLIENT_CERT_HEADER', 'X-Client-Cert')
  end

  # The certificate that arrived with the request, or nil.
  def self.from(request)
    return unless enabled?

    raw = request.headers[header].presence || request.env['SSL_CLIENT_CERT'].presence
    raw && new(OpenSSL::X509::Certificate.new(CGI.unescape(raw.to_s)))
  rescue OpenSSL::X509::CertificateError
    nil
  end

  attr_reader :certificate

  def initialize(certificate)
    @certificate = certificate
  end

  # Section 3.1: the base64url SHA-256 of the DER encoding, as `x5t#S256`.
  def thumbprint
    Base64.urlsafe_encode64(Digest::SHA256.digest(certificate.to_der), padding: false)
  end

  # Section 2.1.2: the registered subject DN or subject alternative name.
  def matches?(client)
    expected = {
      dns: client.tls_client_auth_san_dns, uri: client.tls_client_auth_san_uri,
      ip: client.tls_client_auth_san_ip, email: client.tls_client_auth_san_email
    }.compact_blank
    return subject_matches?(client.tls_client_auth_subject_dn) if client.tls_client_auth_subject_dn.present?

    expected.one? && expected.all? { |type, value| alternative_names.include?([type, value]) }
  end

  # Section 2.2: the certificate carries the key the client registered.
  def key_of?(client)
    der = certificate.public_key.public_to_der
    client.jwk_set.keys.any? { |x| x.verify_key.public_to_der == der }
  rescue JwksFetcher::Error, JWT::JWKError, OpenSSL::PKey::PKeyError
    false
  end

  private

  def subject_matches?(dn)
    OpenSSL::X509::Name.parse_rfc2253(dn).to_der == certificate.subject.to_der
  rescue OpenSSL::X509::NameError
    false
  end

  def alternative_names
    extension = certificate.extensions.find { |x| x.oid == 'subjectAltName' }
    return [] unless extension

    extension.value.split(/,\s*/).filter_map do |entry|
      kind, value = entry.split(':', 2)
      type = { 'DNS' => :dns, 'URI' => :uri, 'IP Address' => :ip, 'email' => :email }[kind]
      [type, value] if type
    end
  end
end
