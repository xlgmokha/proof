# frozen_string_literal: true

module Scim
  class Visitor
    def initialize(attribute_mappings = {})
      @attribute_mappings = attribute_mappings
    end

    def visit(node)
      attr = attr_from(node)
      case node[:operator].to_s
      when 'and'
        visit(node[:left]).merge(visit(node[:right]))
      when 'or'
        visit(node[:left]).or(visit(node[:right]))
      when 'eq'
        User.where(attr => value_from(node))
      when 'ne'
        User.where.not(attr => value_from(node))
      when 'co'
        User.where("#{attr} like ?", "%#{value_from(node)}%")
      when 'sw'
        User.where("#{attr} like ?", "#{value_from(node)}%")
      when 'ew'
        User.where("#{attr} like ?", "%#{value_from(node)}")
      when 'gt'
        User.where("#{attr} > ?", cast_value_from(node))
      when 'ge'
        User.where("#{attr} >= ?", cast_value_from(node))
      when 'lt'
        User.where("#{attr} < ?", cast_value_from(node))
      when 'le'
        User.where("#{attr} <= ?", cast_value_from(node))
      else
        User.none
      end
    end

    def self.result_for(node)
      new(SCIM::User::ATTRIBUTES).visit(node)
    end

    private

    def value_from(node)
      node[:value].to_s[1..-2]
    end

    def cast_value_from(node)
      DateTime.parse(value_from(node))
    end

    def attr_from(node)
      attribute = node[:attribute].to_s
      @attribute_mappings[attribute] || attribute
    end
  end
end
