# frozen_string_literal: true

class ApplicationRecord < ActiveRecord::Base
  include Flippable
  self.abstract_class = true
end
