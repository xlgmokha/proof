# frozen_string_literal: true

module Scim
  module V2
    class UsersController < ::Scim::Controller
      rescue_from ActiveRecord::RecordNotFound do |_error|
        @resource_id = params[:id] if params[:id].present?
        render "record_not_found", status: :not_found
      end

      def index
        @page, @page_size = page_params
        query = User.all
        @total = query.count
        @users = query.offset(@page - 1).limit(@page_size)
        render formats: :scim, status: :ok
      end

      def show
        @user = User.find(params[:id])
        response.headers['Location'] = scim_v2_user_url(@user)
        fresh_when(@user)
        render formats: :scim, status: :ok
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
        params.permit(:schemas, :userName, :locale, :timezone)
      end

      def page_params
        [
          page_param(:startIndex, default: 1, bottom: 1, top: 100),
          page_param(:count, default: 25, bottom: 0, top: 25)
        ]
      end

      def page_param(key, default:, bottom: 0, top: 250)
        actual = params.fetch(key, default).to_i
        return bottom if actual < bottom
        return top if actual > top
        actual
      end

      def repository(container = Spank::IOC)
        container.resolve(:user_repository)
      end
    end
  end
end
