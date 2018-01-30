module Scim
  module V2
    class ServiceProvidersController < ::Scim::Controller
      def show
        render json: configuration.to_json, status: :ok
      end

      private

      def configuration
        Scim::Shady::ServiceProviderConfig.build do |x|
          x.patch = true
          x.bulk do |y|
            y.supported = false
          end
          x.filter do |y|
            y.supported = false
          end
          x.change_password_supported = false
          x.sort_supported = false
          x.etag_supported = false
          x.add_authentication_scheme(:oauth_bearer_token)
          x.meta do |y|
            y.location = scim_v2_ServiceProviderConfig_url
            y.created_at = y.updated_at = Time.now
            y.version = 1
          end
        end
      end
    end
  end
end
