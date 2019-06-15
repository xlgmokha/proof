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
        visit_and(node)
      when :or
        visit_or(node)
      when :eq
        visit_equals(node)
      when :ne
        visit_not_equals(node)
      when :co
        visit_contains(node)
      when :sw
        visit_starts_with(node)
      when :ew
        visit_ends_with(node)
      when :gt
        visit_greater_than(node)
      when :ge
        visit_greater_than_equals(node)
      when :lt
        visit_less_than(node)
      when :le
        visit_less_than_equals(node)
      when :pr
        visit_presence(node)
      else
        visit_unknown(node)
      end
    end

    private

    def visit_and(node)
      visit(node.left).merge(visit(node.right))
    end

    def visit_or(node)
      visit(node.left).or(visit(node.right))
    end

    def visit_equals(node)
      @clazz.where(attr_for(node) => node.value)
    end

    def visit_not_equals(node)
      @clazz.where.not(attr_for(node) => node.value)
    end

    def visit_contains(node)
      @clazz.where("#{attr_for(node)} LIKE ?", "%#{escape_sql_wildcards(node.value)}%")
    end

    def visit_starts_with(node)
      @clazz.where("#{attr_for(node)} LIKE ?", "#{escape_sql_wildcards(node.value)}%")
    end

    def visit_ends_with(node)
      @clazz.where("#{attr_for(node)} LIKE ?", "%#{escape_sql_wildcards(node.value)}")
    end

    def visit_greater_than(node)
      @clazz.where("#{attr_for(node)} > ?", cast_value_from(node))
    end

    def visit_greater_than_equals(node)
      @clazz.where("#{attr_for(node)} >= ?", cast_value_from(node))
    end

    def visit_less_than(node)
      @clazz.where("#{attr_for(node)} < ?", cast_value_from(node))
    end

    def visit_less_than_equals(node)
      @clazz.where("#{attr_for(node)} <= ?", cast_value_from(node))
    end

    def visit_presence(node)
      @clazz.where.not(attr_for(node) => nil)
    end

    def visit_unknown(_node)
      @clazz.none
    end

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
