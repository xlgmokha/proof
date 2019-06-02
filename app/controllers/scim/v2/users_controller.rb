# frozen_string_literal: true

module Scim
  module V2
    class UsersController < ::Scim::Controller
      include Pageable
      rescue_from ActiveRecord::RecordNotFound do |_error|
        @resource_id = params[:id] if params[:id].present?
        render "record_not_found", status: :not_found
      end

      def index
        @users =
          if params[:filter].present?
            User.order(:created_at).scim_filter_for(params[:filter])
          else
            User.order(:created_at)
          end
        @users = paginate(@users, page: page - 1, page_size: page_size)
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

      def repository(container = Spank::IOC)
        container.resolve(:user_repository)
      end

      def page
        page_param(:startIndex, default: 0, bottom: 1, top: 100)
      end

      def page_size
        page_param(:count, default: 25, bottom: 0, top: 25)
      end
    end
  end
end
