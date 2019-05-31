# frozen_string_literal: true

module Scim
  class Visitor
    def initialize(attribute_mappings = {})
      @attribute_mappings = attribute_mappings
    end

    def visit(tree)
      attribute = tree[:attribute].to_s
      attr = @attribute_mappings[attribute] || attribute

      case tree[:operator].to_s
      when 'and'
        visit(tree[:left]).merge(visit(tree[:right]))
      when 'or'
        visit(tree[:left]).or(visit(tree[:right]))
      when 'eq'
        User.where(attr => value_from(tree))
      when 'ne'
        User.where.not(attr => value_from(tree))
      when 'co'
        User.where("#{attr} like ?", "%#{value_from(tree)}%")
      when 'sw'
        User.where("#{attr} like ?", "#{value_from(tree)}%")
      when 'ew'
        User.where("#{attr} like ?", "%#{value_from(tree)}")
      when 'gt'
        value = DateTime.parse(value_from(tree))
        User.where("#{attr} > ?", value)
      when 'ge'
        value = DateTime.parse(value_from(tree))
        User.where("#{attr} >= ?", value)
      when 'lt'
        value = DateTime.parse(value_from(tree))
        User.where("#{attr} < ?", value)
      when 'le'
        value = DateTime.parse(value_from(tree))
        User.where("#{attr} <= ?", value)
      else
        User.none
      end
    end

    def self.result_for(tree)
      new(SCIM::User::ATTRIBUTES).visit(tree)
    end

    private

    def value_from(tree)
      tree[:value].to_s[1..-2]
    end
  end
end
