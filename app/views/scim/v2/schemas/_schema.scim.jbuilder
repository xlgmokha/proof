# frozen_string_literal: true

case schema
when :group
  json.partial! 'group'
when :user
  json.partial! 'user'
end
