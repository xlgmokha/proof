# frozen_string_literal: true

module Scim
  module V2
    class GroupsController < ::Scim::Controller
      include Pageable
      rescue_from ActiveRecord::RecordNotFound do |_error|
        @resource_id = params[:id] if params[:id].present?
        render "scim/record_not_found", status: :not_found
      end

      def index
        groups = ::Group.includes(:users).order(:created_at).scim_search(params[:filter])
        @groups = paginate(groups, page: page - 1, page_size: page_size)
        render formats: :scim, status: :ok
      end

      def show
        @group = repository.find!(params[:id])
        response.headers['Location'] = scim_v2_group_url(@group)
        render formats: :scim, status: :ok
      end

      def create
        @group = repository.create!(group_params)
        response.headers['Location'] = scim_v2_group_url(@group)
        render :show, formats: :scim, status: :created
      end

      def update
        @group = repository.update!(params[:id], group_params)
        response.headers['Location'] = scim_v2_group_url(@group)
        render :show, formats: :scim, status: :ok
      end

      def patch
        @group = repository.patch!(params[:id], Scim::Patch.parse(patch_params))
        response.headers['Location'] = scim_v2_group_url(@group)
        render :show, formats: :scim, status: :ok
      end

      def destroy
        repository.destroy!(params[:id])
        head :no_content
      end

      private

      def group_params
        body = params.to_unsafe_h
        { displayName: body[:displayName], members: body[:members] }
      end

      def patch_params
        params.to_unsafe_h.slice(:schemas, :Operations)
      end

      def repository(container = Spank::IOC)
        container.resolve(:group_repository)
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
