module Scim
  module V2
    class UsersController < ::Scim::Controller
      def index
        render json: {
          schemas: [Scim::Shady::Messages::LIST_RESPONSE],
          totalResults: 0,
          Resources: [],
        }.to_json, status: :ok
      end

      def show
        user = repository.find!(params[:id])
        response.headers['Location'] = scim_v2_users_url(user)
        render json: user.to_scim.to_json, status: :ok
      end

      def create
        user = repository.create!(user_params)
        response.headers['Location'] = scim_v2_users_url(user)
        render json: user.to_scim.to_json, status: :created
      end

      def update
        user = repository.update!(params[:id], user_params)
        response.headers['Location'] = scim_v2_users_url(user)
        render json: user.to_scim.to_json, status: :ok
      end

      def destroy
        repository.destroy!(params[:id])
      end

      private

      def user_params
        params.permit(:schemas, :userName)
      end

      def repository
        UserRepository.new
      end
    end

    class UserRepository
      def find!(id)
        User.find_by!(uuid: id)
      end

      def create!(params)
        password = SecureRandom.hex(32)
        User.create!(email: params[:userName], password: password)
      end

      def update!(id, params)
        user = find!(id)
        user.update!(email: params[:userName])
        user
      end

      def destroy!(id)
        find!(id).destroy!
      end
    end
  end
end
