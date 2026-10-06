# frozen_string_literal: true

class Group < ApplicationRecord
  SCIM_ATTRIBUTES = {
    'id' => :id,
    'displayName' => :display_name,
    'display_name' => :display_name,
    'meta.created' => :created_at,
    'meta.lastModified' => :updated_at,
  }.with_indifferent_access.freeze

  audited
  has_many :group_memberships, dependent: :delete_all
  has_many :users, through: :group_memberships

  validates :display_name, presence: true, uniqueness: { case_sensitive: false }

  scope :scim_search, ->(filter) { Scim::Search.new(Group).for(filter) }

  def self.scim_mapper
    SCIM_ATTRIBUTES
  end
end
