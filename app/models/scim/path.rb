# frozen_string_literal: true

module Scim
  # A SCIM attribute path (RFC 7644 Section 3.10), such as `userName`,
  # `emails.value` or `members[value eq "2819c223"]`.
  class Path
    PATTERN = /
      \A(?:(?<schema>urn:[^\[\]"]+):)?
      (?<attribute>[A-Za-z$][\w$-]*)
      (?:\[(?<filter>.+)\])?
      (?:\.(?<sub_attribute>[A-Za-z$][\w$-]*))?\z
    /x
    FILTER = /\A\s*(?<attribute>[\w$.-]+)\s+(?<operator>\w+)\s+(?<value>.+?)\s*\z/
    Filter = Struct.new(:attribute, :value)

    attr_reader :attribute, :sub_attribute, :filter

    def initialize(attribute:, sub_attribute: nil, filter: nil)
      @attribute = attribute.to_s.downcase
      @sub_attribute = sub_attribute&.downcase
      @filter = filter
    end

    def filter?
      !filter.nil?
    end

    def matches?(item)
      return true unless filter?

      item = item.with_indifferent_access
      key = item.keys.find { |x| x.to_s.casecmp?(filter.attribute) }
      key && item[key] == filter.value
    end

    class << self
      def parse(raw)
        match = PATTERN.match(raw.to_s.strip)
        raise Scim::Error.invalid_path("Invalid path: #{raw}") if match.nil?

        new(
          attribute: match[:attribute],
          sub_attribute: match[:sub_attribute],
          filter: parse_filter(match[:filter])
        )
      end

      private

      def parse_filter(raw)
        return if raw.nil?

        match = FILTER.match(raw)
        unless match && match[:operator].casecmp?('eq')
          raise Scim::Error.new("Unsupported path filter: #{raw}", scim_type: 'invalidFilter')
        end

        Filter.new(match[:attribute], parse_value(match[:value]))
      end

      LITERALS = { 'true' => true, 'false' => false, 'null' => nil }.freeze

      def parse_value(raw)
        return LITERALS[raw] if LITERALS.key?(raw)
        return JSON.parse(raw) if raw.match?(/\A(".*"|-?\d+(\.\d+)?)\z/m)

        raise Scim::Error.new("Invalid filter value: #{raw}", scim_type: 'invalidFilter')
      rescue JSON::ParserError
        raise Scim::Error.new("Invalid filter value: #{raw}", scim_type: 'invalidFilter')
      end
    end
  end
end
