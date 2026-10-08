# frozen_string_literal: true

module Scim
  # An error that can be rendered as a SCIM Error message (RFC 7644 Section 3.12).
  class Error < StandardError
    attr_reader :status, :scim_type

    def initialize(detail, status: 400, scim_type: nil)
      super(detail)
      @status = status
      @scim_type = scim_type
    end

    def to_h
      {
        schemas: [Scim::Kit::V2::Messages::ERROR],
        scimType: scim_type,
        detail: message,
        status: status.to_s,
      }.compact
    end

    class << self
      def invalid_syntax(detail)
        new(detail, scim_type: 'invalidSyntax')
      end

      def invalid_path(detail)
        new(detail, scim_type: 'invalidPath')
      end

      def invalid_value(detail)
        new(detail, scim_type: 'invalidValue')
      end

      def no_target(detail)
        new(detail, scim_type: 'noTarget')
      end

      def mutability(detail)
        new(detail, scim_type: 'mutability')
      end

      def not_found(detail)
        new(detail, status: 404)
      end

      # Translates any exception raised while handling a request.
      def from(error)
        case error
        when Scim::Error then error
        when ActiveRecord::RecordNotFound then not_found(error.message)
        when ActiveRecord::RecordInvalid, ActiveModel::ValidationError then from_validation(error)
        else new('Internal server error', status: 500)
        end
      end

      private

      def from_validation(error)
        model = error.respond_to?(:model) ? error.model : error.record
        if uniqueness?(model.errors)
          new(model.errors.full_messages.join('. '), status: 409, scim_type: 'uniqueness')
        else
          invalid_value(model.errors.full_messages.join('. '))
        end
      end

      def uniqueness?(errors)
        errors.details.values.flatten.any? { |x| x[:error] == :taken }
      end
    end
  end
end
