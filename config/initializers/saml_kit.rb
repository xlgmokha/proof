$next_key_pair_index = 0

class OnDemandRegistry
  def initialize(original)
    @original = original
  end

  def metadata_for(entity_id)
    found = @original.metadata_for(entity_id)
    return found if found

    @original.register_url(entity_id, verify_ssl: Rails.env.production?)
    @original.metadata_for(entity_id)
  end
end

Saml::Kit.configure do |configuration|
  configuration.issuer = ENV['ISSUER']
  configuration.registry = OnDemandRegistry.new(configuration.registry)
  configuration.logger = Rails.logger
  5.times { configuration.generate_key_pair_for(use: :signing) }
end
