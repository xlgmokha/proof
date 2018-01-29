module Scim
  module V2
    class ServiceProvidersController < ::Scim::Controller
      def show
        render json: { schemas: [Scim::Shady::Schemas::SERVICE_PROVIDER_CONFIG] }, status: :ok
      end
    end
  end
end
