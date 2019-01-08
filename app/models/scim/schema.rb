# frozen_string_literal: true

module SCIM
  module Schema
    ERROR = 'urn:ietf:params:scim:api:messages:2.0:Error'
    GROUP = 'urn:ietf:params:scim:schemas:core:2.0:Group'
    RESOURCE_TYPE = 'urn:ietf:params:scim:schemas:core:2.0:ResourceType'
    USER = 'urn:ietf:params:scim:schemas:core:2.0:User'

    def self.group
      url = Spank::IOC.resolve(:url_helpers)

      Scim::Kit::V2::Schema.new(
        id: Scim::Kit::V2::Schemas::GROUP,
        name: "Group",
        location: url.scim_v2_schema_url(id: Scim::Kit::V2::Schemas::GROUP)
      ) do |schema|
        schema.add_attribute(name: 'displayName')
        schema.add_attribute(name: 'members') do |x|
          x.add_attribute(name: 'value') do |y|
            y.mutability = :immutable
          end
          x.add_attribute(name: '$ref') do |y|
            y.reference_types = %w[User Group]
            y.mutability = :immutable
          end
          x.add_attribute(name: 'type') do |y|
            y.canonical_values = %w[User Group]
            y.mutability = :immutable
          end
        end
      end
    end

    def self.user
      url = Spank::IOC.resolve(:url_helpers)

      Scim::Kit::V2::Schema.build(
        id: Scim::Kit::V2::Schemas::USER,
        name: "User",
        location: url.scim_v2_schema_url(id: Scim::Kit::V2::Schemas::USER)
      ) do |schema|
        schema.add_attribute(name: 'userName') do |x|
          x.required = true
          x.uniqueness = :server
        end
        schema.add_attribute(name: 'password') do |x|
          x.mutability = :write_only
          x.required = false
          x.returned = :never
        end
        schema.add_attribute(name: 'emails') do |x|
          x.multi_valued = true
          x.add_attribute(name: 'value')
          x.add_attribute(name: 'primary', type: :boolean)
        end
        schema.add_attribute(name: 'groups') do |x|
          x.multi_valued = true
          x.mutability = :read_only
          x.add_attribute(name: 'value') do |y|
            y.mutability = :read_only
          end
          x.add_attribute(name: '$ref', type: :reference) do |y|
            y.reference_types = %w[User Group]
            y.mutability = :read_only
          end
          x.add_attribute(name: 'display') { |y| y.mutability = :read_only }
        end
        schema.add_attribute(name: 'timezone')
        schema.add_attribute(name: 'locale')
      end
    end
  end
end
