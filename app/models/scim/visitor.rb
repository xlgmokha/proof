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
        User.where(attr => tree[:value].to_s[1..-2])
      when 'ne'
        User.where.not(attr => tree[:value].to_s[1..-2])
      when 'co'
        User.where("#{attr} like ?", "%#{tree[:value].to_s[1..-2]}%")
      when 'sw'
        User.where("#{attr} like ?", "#{tree[:value].to_s[1..-2]}%")
      when 'ew'
        User.where("#{attr} like ?", "%#{tree[:value].to_s[1..-2]}")
      when 'gt'
        value = tree[:value].to_s[1..-2]
        value = DateTime.parse(value)
        User.where("#{attr} > ?", value)
      when 'ge'
        value = tree[:value].to_s[1..-2]
        value = DateTime.parse(value)
        User.where("#{attr} >= ?", value)
      when 'lt'
        value = tree[:value].to_s[1..-2]
        value = DateTime.parse(value)
        User.where("#{attr} < ?", value)
      when 'le'
        value = tree[:value].to_s[1..-2]
        value = DateTime.parse(value)
        User.where("#{attr} <= ?", value)
      else
        User.none
      end
    end

    def self.result_for(tree)
      new(SCIM::User::ATTRIBUTES).visit(tree)
    end
  end
end
