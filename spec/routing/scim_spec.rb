# frozen_string_literal: true

require "rails_helper"

describe "/scim" do
  let(:id) { SecureRandom.uuid }

  %w[users Users].each do |path|
    it { expect(get: "scim/v2/#{path}").to route_to(controller: "scim/v2/users", action: "index", format: :scim) }
    it { expect(get: "scim/v2/#{path}/#{id}").to route_to(controller: "scim/v2/users", action: "show", id: id, format: :scim) }
    it { expect(post: "scim/v2/#{path}").to route_to(controller: "scim/v2/users", action: "create", format: :scim) }
    it { expect(put: "scim/v2/#{path}/#{id}").to route_to(controller: "scim/v2/users", action: "update", id: id, format: :scim) }
    it { expect(patch: "scim/v2/#{path}/#{id}").to route_to(controller: "scim/v2/users", action: "patch", id: id, format: :scim) }
    it { expect(delete: "scim/v2/#{path}/#{id}").to route_to(controller: "scim/v2/users", action: "destroy", id: id, format: :scim) }
  end

  %w[groups Groups].each do |path|
    it { expect(get: "scim/v2/#{path}").to route_to(controller: "scim/v2/groups", action: "index", format: :scim) }
    it { expect(get: "scim/v2/#{path}/#{id}").to route_to(controller: "scim/v2/groups", action: "show", id: id, format: :scim) }
    it { expect(post: "scim/v2/#{path}").to route_to(controller: "scim/v2/groups", action: "create", format: :scim) }
    it { expect(put: "scim/v2/#{path}/#{id}").to route_to(controller: "scim/v2/groups", action: "update", id: id, format: :scim) }
    it { expect(patch: "scim/v2/#{path}/#{id}").to route_to(controller: "scim/v2/groups", action: "patch", id: id, format: :scim) }
    it { expect(delete: "scim/v2/#{path}/#{id}").to route_to(controller: "scim/v2/groups", action: "destroy", id: id, format: :scim) }
  end

  it { expect(get: "scim/v2/Me").to route_to(controller: "scim/v2/mes", action: "show", format: :scim) }
  it { expect(put: "scim/v2/Me").to route_to(controller: "scim/v2/mes", action: "update", format: :scim) }
  it { expect(patch: "scim/v2/Me").to route_to(controller: "scim/v2/mes", action: "patch", format: :scim) }
  it { expect(delete: "scim/v2/Me").to route_to(controller: "scim/v2/mes", action: "destroy", format: :scim) }
  it { expect(post: "scim/v2/Bulk").to route_to(controller: "scim/v2/bulk", action: "create", format: :scim) }
  it { expect(get: "scim/v2/ServiceProviderConfig").to route_to(controller: "scim/v2/service_providers", action: "show", format: :scim) }
  it { expect(get: "scim/v2/ResourceTypes").to route_to(controller: "scim/v2/resource_types", action: "index", format: :scim) }
  it { expect(get: "scim/v2/schemas").to route_to(controller: "scim/v2/schemas", action: "index", format: :scim) }
end
