module Scim
  module V2
    class UsersController < ApplicationController
      def create
        @user = User.create!(
          email: user_params[:userName],
          password: SecureRandom.hex(32),
        )
        response.headers['Content-Type'] = 'application/scim+json'
        response.headers['Location'] = scim_v2_users_url(@user)
        render json: @user.to_scim(self), status: :created
      end

      private

      def authenticate!
      end

      def user_params
        params.permit(:schemas, :userName)
      end
    end
  end
end
