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
        Scim::Kit::V2.configuration.service_provider_configuration
      end
    end
  end
end
