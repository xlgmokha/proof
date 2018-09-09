class Token < ApplicationRecord
  belongs_to :subject, polymorphic: true
  belongs_to :audience, polymorphic: true
end
