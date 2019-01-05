# frozen_string_literal: true

module Scim
  module V2
    class ServiceProvidersController < ::Scim::Controller
      skip_before_action :authenticate!

      def show
        render json: configuration.to_json, status: :ok
      end

      private

      def configuration
        x = Scim::Kit::V2::ServiceProviderConfiguration.new(
          location: scim_v2_ServiceProviderConfig_url
        )
        x.documentation_uri = documentation_url
        x.add_authentication(:oauthbearertoken, primary: true)
        x.meta.version = 1
        x
      end
    end
  end
end
