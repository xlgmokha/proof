ActiveSupport::Notifications.subscribe 'proof.routes_loaded' do
  url_helpers = Rails.application.routes.url_helpers

  Scim::Kit::V2.configure do |config|
    config.service_provider_configuration(location: url_helpers.scim_v2_ServiceProviderConfig_url) do |x|
      x.documentation_uri = url_helpers.documentation_url
      x.add_authentication(:oauthbearertoken, primary: true)
    end
    config.resource_type(id: 'User', location: url_helpers.scim_v2_resource_type_url(id: 'User')) do |x|
      x.name = 'User'
      x.schema = Scim::Kit::V2::Schemas::USER
      x.endpoint = url_helpers.scim_v2_users_url
    end
    config.resource_type(id: 'Group', location: url_helpers.scim_v2_resource_type_url(id: 'Group')) do |x|
      x.name = 'Group'
      x.schema = Scim::Kit::V2::Schemas::GROUP
      x.endpoint = url_helpers.scim_v2_groups_url
    end
    config.schema(id: Scim::Kit::V2::Schemas::USER, name: "User", location: url_helpers.scim_v2_schema_url(id: Scim::Kit::V2::Schemas::USER)) do |schema|
      schema.add_attribute(name: :user_name) do |x|
        x.required = true
        x.uniqueness = :server
      end
      schema.add_attribute(name: :password) do |x|
        x.mutability = :write_only
        x.required = false
        x.returned = :never
      end
      schema.add_attribute(name: :emails) do |x|
        x.multi_valued = true
        x.add_attribute(name: :value)
        x.add_attribute(name: :primary, type: :boolean)
      end
      schema.add_attribute(name: :groups) do |x|
        x.multi_valued = true
        x.mutability = :read_only
        x.add_attribute(name: :value) do |y|
          y.mutability = :read_only
        end
        x.add_attribute(name: '$ref', type: :reference) do |y|
          y.reference_types = %w[User Group]
          y.mutability = :read_only
        end
        x.add_attribute(name: :display) do |y|
          y.mutability = :read_only
        end
      end
      schema.add_attribute(name: :timezone)
      schema.add_attribute(name: :locale)
    end
    config.schema(id: Scim::Kit::V2::Schemas::GROUP, name: "Group", location: url_helpers.scim_v2_schema_url(id: Scim::Kit::V2::Schemas::GROUP)) do |schema|
      schema.add_attribute(name: :display_name)
      schema.add_attribute(name: :members) do |x|
        x.multi_valued = true
        x.add_attribute(name: :value) do |y|
          y.mutability = :immutable
        end
        x.add_attribute(name: '$ref') do |y|
          y.reference_types = %w[User Group]
          y.mutability = :immutable
        end
        x.add_attribute(name: :type) do |y|
          y.canonical_values = %w[User Group]
          y.mutability = :immutable
        end
      end
    end
  end
end
