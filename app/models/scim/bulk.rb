# frozen_string_literal: true

module Scim
  # Processes a SCIM bulk request (RFC 7644 Section 3.7).
  #
  # Operations run in order and are independent of one another: a failed
  # operation is rolled back and reported, but earlier ones remain applied.
  # A POST's bulkId can be referenced by later operations, either as
  # "bulkId:<id>" in a path or as a string value in the data.
  class Bulk
    MAX_OPERATIONS = 100
    MAX_PAYLOAD_SIZE = 1.megabyte

    def initialize(users: Spank::IOC.resolve(:user_repository),
                   groups: Spank::IOC.resolve(:group_repository),
                   url_helpers: Rails.application.routes.url_helpers)
      @repositories = { 'users' => users, 'groups' => groups }
      @url_helpers = url_helpers
    end

    def call(body)
      body = body.to_h.with_indifferent_access
      operations = validate!(body)
      handler = Scim::BulkOperation.new(@repositories, Scim::BulkIds.new, @url_helpers)
      { schemas: [Scim::Kit::V2::Messages::BULK_RESPONSE], Operations: run(operations, handler, body[:failOnErrors].to_i) }
    end

    private

    def run(operations, handler, fail_on_errors)
      failures = 0
      operations.each_with_object([]) do |operation, results|
        results << perform(handler, operation.to_h.with_indifferent_access)
        failures += 1 if results.last[:status].to_i >= 400
        break results if fail_on_errors.positive? && failures >= fail_on_errors
      end
    end

    def validate!(body)
      unless Array(body[:schemas]).include?(Scim::Kit::V2::Messages::BULK_REQUEST)
        raise Scim::Error.invalid_syntax("schemas must include #{Scim::Kit::V2::Messages::BULK_REQUEST}")
      end

      operations = body[:Operations]
      unless operations.is_a?(Array) && operations.any? && operations.all?(Hash)
        raise Scim::Error.invalid_syntax('Operations must be a non-empty array')
      end
      raise too_many if operations.size > MAX_OPERATIONS

      operations
    end

    def too_many
      Scim::Error.new(
        "The number of operations exceeds the maximum of #{MAX_OPERATIONS}", status: 413, scim_type: 'tooMany'
      )
    end

    def perform(handler, operation)
      method = operation[:method].to_s.upcase
      result = { method: method, bulkId: operation[:bulkId].presence }.compact
      ActiveRecord::Base.transaction(requires_new: true) do
        result.merge!(handler.execute(method, operation))
      end
      result
    rescue StandardError => error
      Rails.logger.error(error) unless error.is_a?(Scim::Error)
      failure = Scim::Error.from(error)
      result.merge(status: failure.status.to_s, response: failure.to_h)
    end
  end
end
