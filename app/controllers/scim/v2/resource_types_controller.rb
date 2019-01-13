# frozen_string_literal: true

module Scim
  module V2
    class ResourceTypesController < ::Scim::Controller
      skip_before_action :authenticate!

      def index
        render status: :ok, json: resource_types.values.to_json
      end

      def show
        current_resource = resource_types[params[:id]]
        raise ActiveRecord::RecordNotFound unless current_resource
        render status: :ok, json: current_resource.to_json
      end

      private

      def resource_types
        Scim::Kit::V2.configuration.resource_types
      end
    end
  end
end
