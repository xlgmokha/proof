module Scim
  module V2
    class SearchController < ::Scim::Controller
      def index
        response.headers['Content-Type'] = 'application/scim+json'
        render json: {
          schemas: [Scim::Shady::Messages::LIST_RESPONSE],
          totalResults: 0,
          itemsPerPage: 0,
          startIndex: 1,
          Resources: [],
        }.to_json, status: :ok
      end
    end
  end
end
