# frozen_string_literal: true

module Scim
  class Visitor
    include Varkon

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
        @clazz.where(attr_for(node) => node.value)
      when :ne
        @clazz.where.not(attr_for(node) => node.value)
      when :co
        @clazz.where("#{attr_for(node)} LIKE ?", "%#{escape_sql_wildcards(node.value)}%")
      when :sw
        @clazz.where("#{attr_for(node)} LIKE ?", "#{escape_sql_wildcards(node.value)}%")
      when :ew
        @clazz.where("#{attr_for(node)} LIKE ?", "%#{escape_sql_wildcards(node.value)}")
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

    private

    def cast_value_from(node)
      case @clazz.columns_hash[attr_for(node).to_s].type
      when :datetime
        DateTime.parse(node.value)
      else
        node.value.to_s
      end
    end

    def attr_for(node)
      @mapper[node.attribute] || node.attribute
    end
  end
end
