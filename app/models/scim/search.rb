# frozen_string_literal: true

module Scim
  class Search
    class Node
      def initialize(hash)
        @hash = hash
      end

      def operator
        self[:operator].to_sym
      end

      def attribute
        self[:attribute].to_s
      end

      def value
        self[:value].to_s[1..-2]
      end

      def not?
        @hash.key?(:not)
      end

      def accept(visitor)
        visitor.visit(self)
      end

      def left
        self.class.new(self[:left])
      end

      def right
        self.class.new(self[:right])
      end

      def inspect
        @hash.inspect
      end

      private

      def [](key)
        @hash[key]
      end
    end

    def initialize(clazz)
      @clazz = clazz
    end

    def for(filter)
      return @clazz.all if filter.blank?

      node = Scim::Search::Node.new(::Scim::Kit::V2::Filter.new.parse(filter))
      node.accept(Scim::Visitor.new(@clazz, @clazz.scim_mapper))
    end
  end
end
