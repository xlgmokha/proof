# frozen_string_literal: true

module Scim
  module V2
    class SchemasController < ::Scim::Controller
      skip_before_action :authenticate!

      def index
        render json: schemas.values.to_json
      end

      def show
        current_schema = schemas[params[:id]]
        raise ActiveRecord::RecordNotFound unless current_schema
        render json: current_schema.to_json
      end

      private

      def schemas
        Scim::Kit::V2.configuration.schemas
      end
    end
  end
end
