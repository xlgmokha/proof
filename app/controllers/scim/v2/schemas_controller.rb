# frozen_string_literal: true

module Scim
  module V2
    class SchemasController < ::Scim::Controller
      skip_before_action :authenticate!

      def index
        render json: [schema.user, schema.group].to_json
      end

      def show
        render json: current_schema.to_json
      end

      private

      def current_schema(url = request.original_url)
        return schema.group if url.include?(Scim::Kit::V2::Schemas::GROUP)
        return schema.user if url.include?(Scim::Kit::V2::Schemas::USER)
      end

      def schema
        SCIM::Schema
      end
    end
  end
end
