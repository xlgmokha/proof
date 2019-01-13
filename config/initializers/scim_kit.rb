
ActiveSupport::Notifications.subscribe 'proof.routes_loaded' do
  url_helpers = Rails.application.routes.url_helpers

  Scim::Kit::V2.configure do |config|
    config.service_provider_configuration(location: url_helpers.scim_v2_ServiceProviderConfig_url) do |x|
      x.documentation_uri = url_helpers.documentation_url
      x.add_authentication(:oauthbearertoken, primary: true)
    end
  end
end
