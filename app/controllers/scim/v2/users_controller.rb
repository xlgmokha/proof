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
        if params[:filter].present?
          @users = paginate(apply_filter_to(User.order(:created_at), params[:filter]), page: page - 1, page_size: page_size)
        else
          @users = paginate(User.order(:created_at), page: page - 1, page_size: page_size)
        end
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

      def apply_filter_to(scope, raw_filter)
        parser = Scim::Kit::V2::Filter.new
        parse_tree = parser.parse(params[:filter])
        scope.scim_filter_for(parse_tree)
      end
    end
  end
end
