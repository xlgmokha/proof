# frozen_string_literal: true

module Scim
  module V2
    class BulkController < ::Scim::Controller
      before_action :ensure_payload_is_small_enough

      def create
        body = params.to_unsafe_h.slice(:schemas, :failOnErrors, :Operations)
        render json: Scim::Bulk.new.call(body).to_json, status: :ok
      end

      private

      def ensure_payload_is_small_enough
        # content_length is missing for chunked requests, so measure the body.
        size = [request.content_length.to_i, request.body.size].max
        return if size <= Scim::Bulk::MAX_PAYLOAD_SIZE

        raise Scim::Error.new(
          "The payload exceeds the maximum of #{Scim::Bulk::MAX_PAYLOAD_SIZE} bytes",
          status: 413, scim_type: 'tooLarge'
        )
      end
    end
  end
end
