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
        response.headers['Location'] = user.meta.location
        render json: user.to_json, status: :ok
      end

      def create
        user = repository.create!(user_params)
        response.headers['Location'] = user.meta.location
        render json: user.to_json, status: :created
      end

      def update
        user = repository.update!(params[:id], user_params)
        response.headers['Location'] = user.meta.location
        render json: user.to_json, status: :ok
      end

      def destroy
        repository.destroy!(params[:id])
      end

      private

      def user_params
        params.permit(:schemas, :userName)
      end

      def repository
        $container.resolve(:user_repository)
      end
    end
  end
end