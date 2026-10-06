# frozen_string_literal: true

require 'rails_helper'

RSpec.describe '/scim/v2/Me' do
  include_context 'with scim authentication'

  describe "GET /scim/v2/Me" do
    context "when authenticated as a user" do
      before { get '/scim/v2/Me', headers: headers }

      specify { expect(response).to have_http_status(:ok) }
      specify { expect(response.headers['Content-Type']).to eql('application/scim+json') }
      specify { expect(response.headers['Location']).to eql(scim_v2_user_url(user)) }
      specify { expect(json[:id]).to eql(user.to_param) }
      specify { expect(json[:userName]).to eql(user.email) }
      specify { expect(json[:meta][:location]).to eql(scim_v2_user_url(user)) }
    end

    context "when the user is a member of a group" do
      let!(:group) { create(:group, users: [user]) }

      before { get '/scim/v2/Me', headers: headers }

      specify { expect(json[:groups].pluck(:value)).to eql([group.to_param]) }
    end

    context "when authenticated as a client" do
      let(:client) { create(:client) }
      let(:token) { create(:access_token, subject: client, audience: client).to_jwt }

      before { get '/scim/v2/Me', headers: headers }

      specify { expect(response).to have_http_status(:not_found) }
    end

    context "when not authenticated" do
      before { get '/scim/v2/Me' }

      specify { expect(response).to have_http_status(:unauthorized) }
    end
  end

  describe "PUT /scim/v2/Me" do
    let(:body) { { schemas: [Scim::Kit::V2::Schemas::USER], userName: generate(:email), locale: 'ja', timezone: 'Asia/Tokyo' } }

    before { put '/scim/v2/Me', headers: headers, params: body.to_json }

    specify { expect(response).to have_http_status(:ok) }
    specify { expect(json[:userName]).to eql(body[:userName]) }
    specify { expect(user.reload.email).to eql(body[:userName]) }
    specify { expect(user.reload.locale).to eql('ja') }
  end

  describe "PATCH /scim/v2/Me" do
    before { patch '/scim/v2/Me', headers: headers, params: patch_body({ op: 'replace', path: 'locale', value: 'ja' }) }

    specify { expect(response).to have_http_status(:ok) }
    specify { expect(json[:locale]).to eql('ja') }
    specify { expect(user.reload.locale).to eql('ja') }

    context "when changing the password" do
      before { patch '/scim/v2/Me', headers: headers, params: patch_body({ op: 'replace', path: 'password', value: 'secret-password' }) }

      specify { expect(response).to have_http_status(:ok) }
      specify { expect(user.reload.authenticate('secret-password')).to be_truthy }
    end
  end

  describe "DELETE /scim/v2/Me" do
    before { delete '/scim/v2/Me', headers: headers }

    specify { expect(response).to have_http_status(:no_content) }
    specify { expect(User.exists?(user.id)).to be(false) }
  end
end
