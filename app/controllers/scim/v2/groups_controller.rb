# frozen_string_literal: true

module Scim
  module V2
    class GroupsController < ::Scim::Controller
      def index
        render json: {
          schemas: [Scim::Shady::Messages::LIST_RESPONSE],
          totalResults: User.count,
          Resources: resources,
        }.to_json, status: :ok
      end

      private

      def resources
        User.pluck(:id, :email).map do |x|
          { id: x[0], userName: x[1] }
        end
      end
    end
  end
end
