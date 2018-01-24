module Scim
  module V2
    class UsersController < ::Scim::Controller
      def index
        response.headers['Content-Type'] = 'application/scim+json'
        render json: {
          schemas: [Scim::Shady::Messages::LIST_RESPONSE],
          totalResults: 0,
          Resources: [],
        }.to_json, status: :ok
      end

      def show
        user = User.find_by(uuid: params[:id])
        response.headers['Content-Type'] = 'application/scim+json'
        response.headers['Location'] = scim_v2_users_url(user)
        render json: user.to_scim(self).to_json, status: :ok
      end

      def create
        user = User.create!(
          email: user_params[:userName],
          password: SecureRandom.hex(32),
        )
        response.headers['Content-Type'] = 'application/scim+json'
        response.headers['Location'] = scim_v2_users_url(user)
        render json: user.to_scim(self).to_json, status: :created
      end

      private

      def user_params
        params.permit(:schemas, :userName)
      end
    end
  end
end
