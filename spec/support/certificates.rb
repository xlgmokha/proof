# frozen_string_literal: true

# Builds TLS client certificates (RFC 8705) for specs.
module CertificateHelpers
  def build_certificate(key: OpenSSL::PKey::RSA.generate(2048), subject: '/CN=client.example.com', dns: nil)
    certificate = OpenSSL::X509::Certificate.new
    certificate.version = 2
    certificate.serial = SecureRandom.random_number(2**32)
    certificate.subject = certificate.issuer = OpenSSL::X509::Name.parse(subject)
    certificate.public_key = key.public_key
    certificate.not_before = 1.hour.ago
    certificate.not_after = 1.year.from_now
    if dns
      factory = OpenSSL::X509::ExtensionFactory.new
      factory.subject_certificate = factory.issuer_certificate = certificate
      certificate.add_extension(factory.create_extension('subjectAltName', "DNS:#{dns}"))
    end
    certificate.sign(key, OpenSSL::Digest.new('SHA256'))
    certificate
  end

  def certificate_header(certificate, header = 'X-Client-Cert')
    { header => CGI.escape(certificate.to_pem) }
  end

  def certificate_thumbprint(certificate)
    Base64.urlsafe_encode64(Digest::SHA256.digest(certificate.to_der), padding: false)
  end
end

RSpec.configure { |config| config.include CertificateHelpers }
