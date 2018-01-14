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
        render json: map_from(@user), status: :created
      end

      private

      def authenticate!
      end

      def user_params
        params.permit(:schemas, :userName)
      end

      def map_from(user)
        Scim::Shady::User.build do |x|
          x.id = user.uuid
          x.username = user.email
          x.created_at = user.created_at
          x.updated_at = user.updated_at
          x.location = scim_v2_users_url(self)
          x.version = user.lock_version
        end
      end
    end
  end
end
