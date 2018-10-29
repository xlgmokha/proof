# frozen_string_literal: true

class OnDemandRegistry < Saml::Kit::DefaultRegistry
  def metadata_for(entity_id)
    found = super(entity_id)
    return found if found

    register_url(entity_id, verify_ssl: Rails.env.production?)
    super(entity_id)
  end
end

Saml::Kit.configure do |x|
  x.entity_id = ENV['ISSUER']
  x.registry = OnDemandRegistry.new
  x.logger = Rails.logger
  if ENV['SAML_PRIVATE_KEY'].present? && ENV['SAML_X509_CERTIFICATE'].present?
    x.add_key_pair(
      ENV['SAML_X509_CERTIFICATE'],
      ENV['SAML_PRIVATE_KEY'],
      use: :signing
    )
  else
    5.times { x.generate_key_pair_for(use: :signing) }
  end
end
