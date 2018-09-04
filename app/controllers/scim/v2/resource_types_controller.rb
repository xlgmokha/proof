# frozen_string_literal: true

module Scim
  module V2
    class ResourceTypesController < ::Scim::Controller
      def index
        render status: :ok
      end

      def show
        if params[:id] == 'User'
          render partial: 'user', formats: :scim, status: :ok
        elsif params[:id] == 'Group'
          render partial: 'group', formats: :scim, status: :ok
        else
          raise ActiveRecord::RecordNotFound
        end
      end
    end
  end
end
