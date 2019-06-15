# frozen_string_literal: true

module Scim
  class Visitor
    include Varkon

    def initialize(clazz, mapper = {})
      @clazz = clazz
      @mapper = mapper
    end

    def visit(node)
      visitor_for(node).call(node)
    end

    private

    def visitor_for(node)
      visitors[node.operator] || ->(x) { visit_unknown(x) }
    end

    def visitors
      @visitors ||= {
        and: ->(x) { visit_and(x) },
        co: ->(x) { visit_contains(x) },
        eq: ->(x) { visit_equals(x) },
        ew: ->(x) { visit_ends_with(x) },
        ge: ->(x) { visit_greater_than_equals(x) },
        gt: ->(x) { visit_greater_than(x) },
        le: ->(x) { visit_less_than_equals(x) },
        lt: ->(x) { visit_less_than(x) },
        ne: ->(x) { visit_not_equals(x) },
        or: ->(x) { visit_or(x) },
        pr: ->(x) { visit_presence(x) },
        sw: ->(x) { visit_starts_with(x) },
      }
    end

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
      @mapper[node.attribute] || node.attribute
    end
  end
end
