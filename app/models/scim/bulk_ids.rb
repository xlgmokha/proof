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

    REFERENCE_KEYS = %w[value $ref].freeze

    # Resolves references in a parsed JSON structure. Only reference fields
    # (such as members[].value) are rewritten so that free text, for example a
    # password or displayName that happens to start with "bulkId:", is kept.
    def resolve_all(value, key = nil)
      case value
      when Hash then value.to_h { |k, v| [k, resolve_all(v, k.to_s)] }
      when Array then value.map { |x| resolve_all(x, key) }
      when String then reference_key?(key) ? resolve(value) : value
      else value
      end
    end

    private

    def reference_key?(key)
      REFERENCE_KEYS.include?(key&.downcase)
    end
  end
end
