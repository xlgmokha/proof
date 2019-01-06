# frozen_string_literal: true

module Scim
  module V2
    class ResourceTypesController < ::Scim::Controller
      skip_before_action :authenticate!

      def index
        render status: :ok, json: [user_resource, group_resource].to_json
      end

      def show
        render status: :ok, json: current_resource.to_json
      end

      private

      def current_resource(id = params[:id])
        if id == 'User'
          user_resource
        elsif id == 'Group'
          group_resource
        else
          raise ActiveRecord::RecordNotFound
        end
      end

      def user_resource
        location = scim_v2_resource_type_url(id: 'User')
        Scim::Kit::V2::ResourceType.build(location: location) do |x|
          x.id = 'User'
          x.name = 'User'
          x.schema = Scim::Kit::V2::Schemas::USER
          x.description = 'User Account'
          x.endpoint = scim_v2_users_url
        end
      end

      def group_resource
        location = scim_v2_resource_type_url(id: 'Group')
        Scim::Kit::V2::ResourceType.build(location: location) do |x|
          x.id = 'Group'
          x.name = 'Group'
          x.schema = Scim::Kit::V2::Schemas::GROUP
          x.description = 'Group'
          x.endpoint = scim_v2_groups_url
        end
      end
    end
  end
end
