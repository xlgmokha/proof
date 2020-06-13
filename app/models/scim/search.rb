# frozen_string_literal: true

module Scim
  class Search
    def initialize(clazz)
      @clazz = clazz
    end

    def for(filter)
      return @clazz.all if filter.blank?

      ::Scim::Kit::V2::Filter
        .parse(filter)
        .accept(Scim::Visitor.new(@clazz, @clazz.scim_mapper))
    end
  end
end
