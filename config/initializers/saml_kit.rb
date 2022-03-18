# frozen_string_literal: true

class OnDemandRegistry < Saml::Kit::DefaultRegistry
  REGEX = /\/sso\/saml\/samlconf-(?<uuid>[A-Za-z0-9]+)\/metadata/

  def metadata_for(entity_id)
    found = super(entity_id)
    return found if found

    uri = URI.parse(entity_id)
    if uri.host.include?("terraform.io") || uri.host.include?("ngrok.io")
      metadata = Saml::Kit::Metadata.build do |builder|
        builder.entity_id = entity_id
        builder.build_service_provider do |x|
          match = uri.path.match(REGEX)
          x.add_assertion_consumer_service("https://#{uri.host}/sso/saml/samlconf-#{match[:uuid]}/acs", binding: :http_post)
        end
      end
      Rails.logger.debug(metadata.to_xml(pretty: true))
      register(metadata)
    else
      register_url(entity_id, verify_ssl: Rails.env.production?)
    end

    super(entity_id)
  end
end

Saml::Kit.configure do |x|
  x.entity_id = ENV.fetch('ISSUER', "https://proof.example.com/metadata.xml" )
  x.registry = OnDemandRegistry.new
  x.logger = Rails.logger
  x.add_key_pair(IO.read('tmp/x509.crt'), IO.read('tmp/key.pem'), use: :signing)
end
