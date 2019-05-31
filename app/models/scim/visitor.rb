# frozen_string_literal: true

module Scim
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
      new(Scim::Kit::V2::Filter.new.parse(query))
    end

    private

    def [](key)
      @node[key]
    end
  end

  class Visitor
    def initialize(clazz, mapper = {})
      @clazz = clazz
      @mapper = mapper
    end

    def visit(node)
      case node.operator
      when :and
        visit(node.left).merge(visit(node.right))
      when :or
        visit(node.left).or(visit(node.right))
      when :eq
        @clazz.where(attr_for(node) => value_from(node))
      when :ne
        @clazz.where.not(attr_for(node) => value_from(node))
      when :co
        @clazz.where("#{attr_for(node)} like ?", "%#{value_from(node)}%")
      when :sw
        @clazz.where("#{attr_for(node)} like ?", "#{value_from(node)}%")
      when :ew
        @clazz.where("#{attr_for(node)} like ?", "%#{value_from(node)}")
      when :gt
        @clazz.where("#{attr_for(node)} > ?", cast_value_from(node))
      when :ge
        @clazz.where("#{attr_for(node)} >= ?", cast_value_from(node))
      when :lt
        @clazz.where("#{attr_for(node)} < ?", cast_value_from(node))
      when :le
        @clazz.where("#{attr_for(node)} <= ?", cast_value_from(node))
      when :pr
        @clazz.where.not(attr_for(node) => nil)
      else
        @clazz.none
      end
    end

    def self.result_for(node)
      new(User, SCIM::User::ATTRIBUTES).visit(node)
    end

    private

    def value_from(node)
      node.value
    end

    def cast_value_from(node)
      attr = attr_for(node)
      value = value_from(node)
      type = @clazz.columns_hash[attr.to_s].type

      case type
      when :datetime
        DateTime.parse(value)
      else
        value.to_s
      end
    end

    def attr_for(node)
      @mapper[node.attribute] || node.attribute
    end
  end
end
