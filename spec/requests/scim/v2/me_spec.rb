require 'rails_helper'

describe '/scim/v2/me' do
  it 'returns a 501' do
    get '/scim/v2/me'
    expect(response).to have_http_status(:not_implemented)
  end
end
