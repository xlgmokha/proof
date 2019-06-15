# frozen_string_literal: true

module Scim
  class Visitor
    include Varkon
    VISITORS = {
      and: :visit_and,
      co: :visit_contains,
      eq: :visit_equals,
      ew: :visit_ends_with,
      ge: :visit_greater_than_equals,
      gt: :visit_greater_than,
      le: :visit_less_than_equals,
      lt: :visit_less_than,
      ne: :visit_not_equals,
      or: :visit_or,
      pr: :visit_presence,
      sw: :visit_starts_with,
    }.freeze

    def initialize(clazz, mapper = {})
      @clazz = clazz
      @mapper = mapper
    end

    def visit(node)
      visitor_for(node).call(node)
    end

    private

    def visitor_for(node)
      method(VISITORS.fetch(node.operator, :visit_unknown))
    end

    def visit_and(node)
      visit(node.left).merge(visit(node.right))
    end

    def visit_or(node)
      visit(node.left).or(visit(node.right))
    end

    def visit_equals(node)
      if node.not?
        @clazz.where.not(attr_for(node) => node.value)
      else
        @clazz.where(attr_for(node) => node.value)
      end
    end

    def visit_not_equals(node)
      @clazz.where.not(attr_for(node) => node.value)
    end

    def visit_contains(node)
      @clazz.where(
        "#{attr_for(node)} LIKE ?", "%#{escape_sql_wildcards(node.value)}%"
      )
    end

    def visit_starts_with(node)
      @clazz.where(
        "#{attr_for(node)} LIKE ?", "#{escape_sql_wildcards(node.value)}%"
      )
    end

    def visit_ends_with(node)
      @clazz.where(
        "#{attr_for(node)} LIKE ?", "%#{escape_sql_wildcards(node.value)}"
      )
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
      @mapper.fetch(node.attribute, node.attribute)
    end
  end
end
