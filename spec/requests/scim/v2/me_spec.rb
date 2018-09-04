require 'rails_helper'

RSpec.describe '/scim/v2/Me' do
  describe "GET /scim/v2/Me" do
    before { get '/scim/v2/Me' }
    specify { expect(response).to have_http_status(:not_implemented) }
  end
end
