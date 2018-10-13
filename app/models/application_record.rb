# frozen_string_literal: true

class ApplicationRecord < ActiveRecord::Base
  UUID = /\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/
  URI_REGEX = /\A#{URI.regexp(%w[http https])}\z/

  include Flippable
  self.abstract_class = true
end
