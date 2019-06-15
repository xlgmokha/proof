# frozen_string_literal: true

module Scim
  class Search
    class Node
      def initialize(node)
        @node = node
      end

      def operator
        @node[:operator].to_sym
      end

      def attribute
        @node[:attribute].to_s
      end

      def value
        @node[:value].to_s[1..-2]
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

      def self.parse(query)
        new(::Scim::Kit::V2::Filter.new.parse(query))
      end

      private

      def [](key)
        @node[key]
      end
    end

    def initialize(clazz)
      @clazz = clazz
    end

    def for(filter)
      node = Scim::Search::Node.parse(filter)
      node.accept(Scim::Visitor.new(@clazz, @clazz.scim_mapper))
    end

    def self.for(filter, clazz)
      new(clazz).for(filter)
    end
  end
end
