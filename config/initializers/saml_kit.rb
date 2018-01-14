class OnDemandRegistry < SimpleDelegator
  def metadata_for(entity_id)
    found = __getobj__.metadata_for(entity_id)
    return found if found

    __getobj__.register_url(entity_id, verify_ssl: Rails.env.production?)
    __getobj__.metadata_for(entity_id)
  end
end

Saml::Kit.configure do |configuration|
  configuration.issuer = ENV['ISSUER']
  configuration.registry = OnDemandRegistry.new(configuration.registry)
  configuration.logger = Rails.logger
  5.times { configuration.generate_key_pair_for(use: :signing) }
end
