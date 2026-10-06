# frozen_string_literal: true

module Scim
  # A SCIM PATCH request (RFC 7644 Section 3.5.2). Operations are applied, in
  # order, to a target that implements #add, #replace and #remove, each taking a
  # Scim::Path and, except for #remove, a value.
  class Patch
    OPERATIONS = %w[add remove replace].freeze
    Operation = Struct.new(:op, :path, :value) do
      def path?
        !path.nil?
      end
    end

    attr_reader :operations

    def initialize(operations)
      @operations = operations
    end

    def apply_to(target)
      operations.each { |x| apply(target, x) }
      target
    end

    class << self
      def parse(body)
        body = (body || {}).to_h.with_indifferent_access
        unless Array(body[:schemas]).include?(Scim::Kit::V2::Messages::PATCH_OP)
          raise Scim::Error.invalid_syntax("schemas must include #{Scim::Kit::V2::Messages::PATCH_OP}")
        end

        operations = body[:Operations]
        unless operations.is_a?(Array) && operations.any?
          raise Scim::Error.invalid_syntax('Operations must be a non-empty array')
        end

        new(operations.map { |x| build(x) })
      end

      private

      def build(raw)
        raise Scim::Error.invalid_syntax('Operation must be an object') unless raw.respond_to?(:to_h)

        raw = raw.to_h.with_indifferent_access
        op = raw[:op].to_s.downcase
        raise Scim::Error.invalid_syntax("Unsupported op: #{raw[:op]}") unless OPERATIONS.include?(op)

        path = raw[:path].presence && Scim::Path.parse(raw[:path])
        validate!(op, path, raw)
        Operation.new(op, path, raw[:value])
      end

      def validate!(action, path, raw)
        raise Scim::Error.no_target('remove requires a path') if action == 'remove' && path.nil?
        return if action == 'remove' || raw.key?(:value)

        raise Scim::Error.invalid_value("#{action} requires a value")
      end
    end

    private

    def apply(target, operation)
      if operation.path?
        dispatch(target, operation.op, operation.path, operation.value)
      else
        # Without a path the value is an object of attributes (Section 3.5.2.1)
        unless operation.value.respond_to?(:to_h) && !operation.value.is_a?(Array)
          raise Scim::Error.invalid_value('value must be an object when no path is given')
        end

        operation.value.to_h.each do |key, value|
          dispatch(target, operation.op, Scim::Path.parse(key), value)
        end
      end
    end

    def dispatch(target, action, path, value)
      action == 'remove' ? target.remove(path) : target.public_send(action, path, value)
    end
  end
end
