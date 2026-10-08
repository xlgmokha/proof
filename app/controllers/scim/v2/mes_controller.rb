# frozen_string_literal: true

module Scim
  module V2
    # The authenticated subject's own User resource (RFC 7644 Section 3.11).
    class MesController < UsersController
      before_action :use_current_user

      private

      def use_current_user
        return not_found unless current_user.is_a?(::User)

        params[:id] = current_user.to_param
      end

      def not_found
        @resource_id = 'Me'
        render "scim/record_not_found", status: :not_found
      end
    end
  end
end
