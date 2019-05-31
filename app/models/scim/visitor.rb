# frozen_string_literal: true

module Scim
  class Visitor
    def initialize(clazz, mapper = {})
      @clazz = clazz
      @mapper = mapper
    end

    def visit(node)
      case node[:operator].to_sym
      when :and
        visit(node[:left]).merge(visit(node[:right]))
      when :or
        visit(node[:left]).or(visit(node[:right]))
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
      else
        @clazz.none
      end
    end

    def self.result_for(node)
      new(User, SCIM::User::ATTRIBUTES).visit(node)
    end

    private

    def value_from(node)
      node[:value].to_s[1..-2]
    end

    def cast_value_from(node)
      DateTime.parse(value_from(node))
    end

    def attr_for(node)
      attribute = node[:attribute].to_s
      @mapper[attribute] || attribute
    end
  end
end
