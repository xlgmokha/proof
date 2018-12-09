# frozen_string_literal: true

module ApplicationHelper
  def alert_class_for(type)
    case type.to_sym
    when :notice
      'is-success'
    when :warning
      'is-warning'
    when :error
      'is-danger'
    else
      'is-info'
    end
  end
end
