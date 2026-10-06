# frozen_string_literal: true

module Scim
  # Tracks the resources created by a bulk request so later operations can refer
  # to them as "bulkId:<id>" (RFC 7644 Section 3.7.2).
  class BulkIds
    REFERENCE = /\Abulk[iI]d:(?<id>.+)\z/

    def initialize
      @ids = {}
    end

    # Claims a bulkId before its resource is created so duplicates are rejected.
    def reserve(bulk_id)
      raise Scim::Error.invalid_syntax("Duplicate bulkId: #{bulk_id}") if @ids.key?(bulk_id)

      @ids[bulk_id] = nil
    end

    def bind(bulk_id, resource_id)
      @ids[bulk_id] = resource_id.to_s
    end

    def resolve(value)
      match = REFERENCE.match(value.to_s)
      return value if match.nil?

      @ids[match[:id]] || raise(Scim::Error.new("Unresolved bulkId: #{match[:id]}", status: 409,
        scim_type: 'invalidValue'))
    end

    # Resolves every reference found in a parsed JSON structure.
    def resolve_all(value)
      case value
      when Hash then value.transform_values { |x| resolve_all(x) }
      when Array then value.map { |x| resolve_all(x) }
      when String then resolve(value)
      else value
      end
    end
  end
end
