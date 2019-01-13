
ActiveSupport::Notifications.subscribe 'proof.routes_loaded' do
  url_helpers = Rails.application.routes.url_helpers

  Scim::Kit::V2.configure do |config|
    config.service_provider_configuration(location: url_helpers.scim_v2_ServiceProviderConfig_url) do |x|
      x.documentation_uri = url_helpers.documentation_url
      x.add_authentication(:oauthbearertoken, primary: true)
    end
    config.resource_type(id: 'User', location: url_helpers.scim_v2_resource_type_url(id: 'User')) do |x|
      x.name = 'User'
      x.schema = Scim::Kit::V2::Schemas::USER
      x.endpoint = url_helpers.scim_v2_users_url
    end
    config.resource_type(id: 'Group', location: url_helpers.scim_v2_resource_type_url(id: 'Group')) do |x|
      x.name = 'Group'
      x.schema = Scim::Kit::V2::Schemas::GROUP
      x.endpoint = url_helpers.scim_v2_groups_url
    end
  end
end
