# frozen_string_literal: true

module Scim
  module V2
    class SearchController < ::Scim::Controller
      include Pageable

      def index
        @users = User.order(:created_at).scim_search(params[:filter])
        @users = paginate(@users, page: page - 1, page_size: page_size)
        render formats: :scim, status: :ok
      end

      private

      def page
        page_param(:startIndex, default: 0, bottom: 1, top: 100)
      end

      def page_size
        page_param(:count, default: 25, bottom: 0, top: 25)
      end
    end
  end
end
