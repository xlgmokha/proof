# frozen_string_literal: true

module Scim
  # Executes a single operation of a bulk request and returns its status and,
  # for created and updated resources, its location.
  class BulkOperation
    METHODS = %w[POST PUT PATCH DELETE].freeze
    PATH = %r{\A/(?<type>Users|Groups)(?:/(?<id>[^/]+))?\z}i

    # url_helpers must respond to scim_v2_user_url and scim_v2_group_url
    def initialize(repositories, ids, url_helpers)
      @repositories = repositories
      @ids = ids
      @url_helpers = url_helpers
    end

    def execute(method, operation)
      raise Scim::Error.invalid_syntax("Unsupported method: #{operation[:method]}") unless METHODS.include?(method)

      type, id = target_for(operation[:path])
      repository = @repositories.fetch(type)
      case method
      when 'POST' then create(type, repository, operation)
      when 'PUT' then update(type, repository, id, operation)
      when 'PATCH' then patch(type, repository, id, operation)
      else destroy(repository, id)
      end
    end

    private

    def create(type, repository, operation)
      bulk_id = operation[:bulkId]
      raise Scim::Error.invalid_syntax('POST requires a bulkId') if bulk_id.blank?

      @ids.reserve(bulk_id)
      resource = repository.create!(data_for(operation))
      @ids.bind(bulk_id, resource.id)
      { status: '201', location: location_for(type, resource.id) }
    end

    def update(type, repository, id, operation)
      require_id!(id)
      resource = repository.update!(id, data_for(operation))
      { status: '200', location: location_for(type, resource.id) }
    end

    def patch(type, repository, id, operation)
      require_id!(id)
      patch = Scim::Patch.parse(data_for(operation))
      if type == 'groups'
        repository.patch!(id, patch)
      else
        Scim::UserPatch.new(::User.find(id)).apply(patch)
      end
      { status: '200', location: location_for(type, id) }
    end

    def destroy(repository, id)
      require_id!(id)
      repository.destroy!(id)
      { status: '204' }
    end

    def require_id!(id)
      raise Scim::Error.invalid_syntax('path must include a resource id') if id.blank?
    end

    def target_for(path)
      match = PATH.match(path.to_s)
      raise Scim::Error.invalid_path("Unsupported path: #{path}") if match.nil?

      [match[:type].downcase, @ids.resolve(match[:id])]
    end

    def data_for(operation)
      data = operation[:data]
      raise Scim::Error.invalid_syntax('data must be an object') unless data.is_a?(Hash)

      @ids.resolve_all(data).with_indifferent_access
    end

    def location_for(type, id)
      helper = type == 'groups' ? :scim_v2_group_url : :scim_v2_user_url
      @url_helpers.public_send(helper, id: id)
    end
  end
end
