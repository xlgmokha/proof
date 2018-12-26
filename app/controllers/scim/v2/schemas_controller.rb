# frozen_string_literal: true

module Scim
  module V2
    class SchemasController < ::Scim::Controller
      skip_before_action :authenticate!

      def index
        render json: [user_schema, group_schema].to_json
      end

      def show
        render json: current_schema.to_json
      end

      private

      def current_schema(url = request.original_url)
        return group_schema if url.include?(Scim::Kit::V2::Schema::GROUP)
        return user_schema if url.include?(Scim::Kit::V2::Schema::USER)
      end

      def user_schema
        Scim::Kit::V2::Schema.build(
          id: Scim::Kit::V2::Schema::USER,
          name: "User",
          location: scim_v2_schema_url(id: Scim::Kit::V2::Schema::USER)
        ) do |schema|
          schema.description = "User Account"
          schema.add_attribute(name: 'userName') do |x|
            x.description = "Unique identifier for the User"
            x.required = true
            x.uniqueness = :server
          end
          schema.add_attribute(name: 'password') do |x|
            x.description = "The User's cleartext password."
            x.mutability = :write_only
            x.required = false
            x.returned = :never
          end
          schema.add_attribute(name: 'emails') do |x|
            x.multi_valued = true
            x.description = "Email addresses for the user."
            x.add_attribute(name: 'value') do |y|
              y.description = "Email addresses for the user."
            end
            x.add_attribute(name: 'primary', type: :boolean) do |y|
              y.description = "A Boolean value indicating the preferred email"
            end
          end
          schema.add_attribute(name: 'groups') do |x|
            x.multi_valued = true
            x.description = "A list of groups to which the user belongs."
            x.mutability = :read_only
            x.add_attribute(name: 'value') do |y|
              y.description = "The identifier of the User's group."
              y.mutability = :read_only
            end
            x.add_attribute(name: '$ref', type: :reference) do |y|
              y.reference_types = %w[User Group]
              y.description = "The URI of the corresponding 'Group' resource."
              y.mutability = :read_only
            end
            x.add_attribute(name: 'display') do |y|
              y.description = "A human-readable name."
              y.mutability = :read_only
            end
          end
        end
      end

      def group_schema
        Scim::Kit::V2::Schema.new(
          id: Scim::Kit::V2::Schema::GROUP,
          name: "Group",
          location: scim_v2_schema_url(id: Scim::Kit::V2::Schema::GROUP)
        ) do |schema|
          schema.description = "Group"
          schema.add_attribute(name: 'displayName') do |x|
            x.description = "A human-readable name for the Group."
          end
          schema.add_attribute(name: 'members') do |x|
            x.description = "A list of members of the Group."
            x.add_attribute(name: 'value') do |y|
              y.description = "Identifier of the member of this Group."
              y.mutability = :immutable
            end
            x.add_attribute(name: '$ref') do |y|
              y.description = "The URI corresponding to a SCIM resource."
              y.reference_types = %w[User Group]
              y.mutability = :immutable
            end
            x.add_attribute(name: 'type') do |y|
              y.description = "A label indicating the type of resource"
              y.canonical_values = %w[User Group]
              y.mutability = :immutable
            end
          end
        end
      end
    end
  end
end
