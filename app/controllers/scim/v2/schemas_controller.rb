# frozen_string_literal: true

module Scim
  module V2
    class SchemasController < ::Scim::Controller
      def index
        @schemas = [:user, :group]
        render status: :ok
      end

      def show
        render partial: 'schema', formats: :scim, status: :ok, locals: {
          schema: current_schema
        }
      end

      private

      def current_schema(url = request.original_url)
        return :group if url.include?(SCIM::Schema::GROUP)
        return :user if url.include?(SCIM::Schema::USER)
      end
    end
  end
end
