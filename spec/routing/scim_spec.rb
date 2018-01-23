require "rails_helper"

describe "/scim" do
  let(:id) { SecureRandom.uuid }
  it { expect(get: "scim/v2/users/#{id}").to route_to(controller: "scim/v2/users", action: "show", id: id, format: "json") }
  it { expect(post: "scim/v2/users").to route_to(controller: "scim/v2/users", action: "create", format: "json") }
  it { expect(put: "scim/v2/users/#{id}").to route_to(controller: "scim/v2/users", action: "update", id: id, format: "json") }
  it { expect(patch: "scim/v2/users/#{id}").to route_to(controller: "scim/v2/users", action: "update", id: id, format: "json") }
  it { expect(delete: "scim/v2/users/#{id}").to route_to(controller: "scim/v2/users", action: "destroy", id: id, format: "json") }

  #it { expect(get: "scim/v2/groups/#{id}").to route_to(controller: "scim/v2/groups", action: "show", id: id, format: "json") }
  #it { expect(post: "scim/v2/groups").to route_to(controller: "scim/v2/groups", action: "create", format: "json") }
  #it { expect(put: "scim/v2/groups/#{id}").to route_to(controller: "scim/v2/groups", action: "update", id: id, format: "json") }
  #it { expect(patch: "scim/v2/groups/#{id}").to route_to(controller: "scim/v2/groups", action: "update", id: id, format: "json") }
  #it { expect(delete: "scim/v2/groups/#{id}").to route_to(controller: "scim/v2/groups", action: "destroy", id: id, format: "json") }

  #it { expect(get: "/scim/v2/me").to route_to(controller: 'hi') }
  it { expect(get: "scim/v2/ServiceProviderConfig").to route_to(controller: "scim/v2/service_providers", action: "index", format: "json") }
  it { expect(get: "scim/v2/ResourceTypes").to route_to(controller: "scim/v2/resource_types", action: "index", format: "json") }
  it { expect(get: "scim/v2/schemas").to route_to(controller: "scim/v2/schemas", action: "index", format: "json") }
  #it { expect(post: "scim/v2/bulk").to route_to(controller: "scim/v2/bulk", action: "update", format: "json") }
end
