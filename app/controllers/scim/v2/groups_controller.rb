
# frozen_string_literal: true

module Scim
  module V2
    class GroupsController < ::Scim::Controller
      def index
        render json: {
          schemas: [Scim::Shady::Messages::LIST_RESPONSE],
          totalResults: 0,
          Resources: [],
        }.to_json, status: :ok
      end
    end
  end
end
