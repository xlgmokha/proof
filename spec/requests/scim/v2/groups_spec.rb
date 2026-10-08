# frozen_string_literal: true

require 'rails_helper'

describe "/scim/v2/groups" do
  include_context 'with scim authentication'

  let(:member) { create(:user) }
  let!(:group) { create(:group, users: [member]) }

  describe "GET /scim/v2/Groups" do
    let!(:other_group) { create(:group) }

    context "when authenticated" do
      before { get '/scim/v2/Groups', headers: headers }

      specify { expect(response).to have_http_status(:ok) }
      specify { expect(response.headers['Content-Type']).to eql('application/scim+json') }
      specify { expect(json[:schemas]).to match_array([Scim::Kit::V2::Messages::LIST_RESPONSE]) }
      specify { expect(json[:totalResults]).to be(2) }
      specify { expect(json[:startIndex]).to be(1) }
      specify { expect(json[:Resources].pluck(:id)).to match_array([group.to_param, other_group.to_param]) }

      it 'includes the members' do
        resource = json[:Resources].find { |x| x[:id] == group.to_param }
        expect(resource[:displayName]).to eql(group.display_name)
        expect(resource[:members]).to eql([{ value: member.to_param, '$ref': scim_v2_user_url(member), type: 'User', display: member.email }])
      end
    end

    context "when using the lowercase endpoint" do
      before { get '/scim/v2/groups', headers: headers }

      specify { expect(response).to have_http_status(:ok) }
      specify { expect(json[:totalResults]).to be(2) }
    end

    context "when the request has no content type" do
      before { get '/scim/v2/Groups', headers: headers.except('Content-Type') }

      specify { expect(response).to have_http_status(:ok) }
    end

    context "when the content type is unsupported" do
      before { get '/scim/v2/Groups', headers: headers.merge('Content-Type' => 'text/plain') }

      specify { expect(response).to have_http_status(:unsupported_media_type) }
    end

    context "when filtering by displayName" do
      before { get '/scim/v2/Groups', params: { filter: %(displayName eq "#{other_group.display_name}") }, headers: headers }

      specify { expect(json[:Resources].pluck(:id)).to eql([other_group.to_param]) }
    end

    context "when paginating" do
      before { get '/scim/v2/Groups', params: { startIndex: 2, count: 1 }, headers: headers }

      specify { expect(json[:totalResults]).to be(2) }
      specify { expect(json[:startIndex]).to be(2) }
      specify { expect(json[:Resources].size).to be(1) }
    end

    context "when the authentication token is invalid" do
      before { get '/scim/v2/Groups', headers: headers.merge('Authorization' => "Bearer #{SecureRandom.uuid}") }

      specify { expect(response).to have_http_status(:unauthorized) }
    end
  end

  describe "GET /scim/v2/Groups/:id" do
    context "when the group exists" do
      before { get "/scim/v2/Groups/#{group.to_param}", headers: headers }

      specify { expect(response).to have_http_status(:ok) }
      specify { expect(response.headers['Location']).to eql(scim_v2_group_url(group)) }
      specify { expect(json[:schemas]).to match_array([Scim::Kit::V2::Schemas::GROUP]) }
      specify { expect(json[:id]).to eql(group.to_param) }
      specify { expect(json[:displayName]).to eql(group.display_name) }
      specify { expect(json[:meta][:resourceType]).to eql('Group') }
      specify { expect(json[:meta][:location]).to eql(scim_v2_group_url(group)) }
      specify { expect(json[:meta][:version]).to be_present }
      specify { expect(json[:members].pluck(:value)).to eql([member.to_param]) }
    end

    context "when the group does not exist" do
      before { get "/scim/v2/Groups/#{SecureRandom.uuid}", headers: headers }

      specify { expect(response).to have_http_status(:not_found) }
      specify { expect(json[:status]).to eql('404') }
    end
  end

  describe "POST /scim/v2/Groups" do
    let(:body) { { schemas: [Scim::Kit::V2::Schemas::GROUP], displayName: 'Engineering', members: [{ value: member.to_param }] } }

    context "when the request is valid" do
      before { post '/scim/v2/Groups', params: body.to_json, headers: headers }

      specify { expect(response).to have_http_status(:created) }
      specify { expect(response.headers['Location']).to eql(scim_v2_group_url(Group.find_by!(display_name: 'Engineering'))) }
      specify { expect(json[:displayName]).to eql('Engineering') }
      specify { expect(json[:members].pluck(:value)).to eql([member.to_param]) }
      specify { expect(Group.find_by!(display_name: 'Engineering').users).to match_array([member]) }
    end

    context "when no members are given" do
      before { post '/scim/v2/Groups', params: body.except(:members).to_json, headers: headers }

      specify { expect(response).to have_http_status(:created) }
      specify { expect(json[:members]).to be_empty }
    end

    context "when the displayName is missing" do
      before { post '/scim/v2/Groups', params: body.except(:displayName).to_json, headers: headers }

      specify { expect(response).to have_http_status(:bad_request) }
      specify { expect(json[:scimType]).to eql('invalidValue') }
    end

    context "when the displayName is already taken" do
      before { post '/scim/v2/Groups', params: body.merge(displayName: group.display_name.upcase).to_json, headers: headers }

      specify { expect(response).to have_http_status(:conflict) }
      specify { expect(json[:scimType]).to eql('uniqueness') }
    end

    context "when a member does not exist" do
      before { post '/scim/v2/Groups', params: body.merge(members: [{ value: SecureRandom.uuid }]).to_json, headers: headers }

      specify { expect(response).to have_http_status(:bad_request) }
      specify { expect(json[:scimType]).to eql('invalidValue') }
      specify { expect(Group.exists?(display_name: 'Engineering')).to be(false) }
    end
  end

  describe "PUT /scim/v2/Groups/:id" do
    let(:new_member) { create(:user) }
    let(:body) { { schemas: [Scim::Kit::V2::Schemas::GROUP], displayName: 'Renamed', members: [{ value: new_member.to_param }] } }

    context "when the request is valid" do
      before { put "/scim/v2/Groups/#{group.to_param}", params: body.to_json, headers: headers }

      specify { expect(response).to have_http_status(:ok) }
      specify { expect(json[:displayName]).to eql('Renamed') }
      specify { expect(json[:members].pluck(:value)).to eql([new_member.to_param]) }
      specify { expect(group.reload.users).to match_array([new_member]) }
    end

    context "when the members are omitted" do
      before { put "/scim/v2/Groups/#{group.to_param}", params: body.except(:members).to_json, headers: headers }

      specify { expect(group.reload.users).to be_empty }
    end

    context "when the group does not exist" do
      before { put "/scim/v2/Groups/#{SecureRandom.uuid}", params: body.to_json, headers: headers }

      specify { expect(response).to have_http_status(:not_found) }
    end
  end

  describe "PATCH /scim/v2/Groups/:id" do
    let(:path) { "/scim/v2/Groups/#{group.to_param}" }
    let(:new_member) { create(:user) }

    context "when renaming the group" do
      before { patch path, params: patch_body({ op: 'replace', path: 'displayName', value: 'Renamed' }), headers: headers }

      specify { expect(response).to have_http_status(:ok) }
      specify { expect(json[:displayName]).to eql('Renamed') }
      specify { expect(group.reload.display_name).to eql('Renamed') }
    end

    context "when adding members" do
      before { patch path, params: patch_body({ op: 'add', path: 'members', value: [{ value: new_member.to_param }, { value: member.to_param }] }), headers: headers }

      specify { expect(response).to have_http_status(:ok) }
      specify { expect(json[:members].pluck(:value)).to match_array([member.to_param, new_member.to_param]) }
      specify { expect(group.reload.users).to match_array([member, new_member]) }
    end

    context "when replacing the members" do
      before { patch path, params: patch_body({ op: 'replace', path: 'members', value: [{ value: new_member.to_param }] }), headers: headers }

      specify { expect(group.reload.users).to match_array([new_member]) }
    end

    context "when removing a member by filter" do
      before do
        group.users << new_member
        patch path, params: patch_body({ op: 'remove', path: %(members[value eq "#{member.to_param}"]) }), headers: headers
      end

      specify { expect(response).to have_http_status(:ok) }
      specify { expect(group.reload.users).to match_array([new_member]) }
    end

    context "when removing a member that is not in the group" do
      before { patch path, params: patch_body({ op: 'remove', path: %(members[value eq "#{new_member.to_param}"]) }), headers: headers }

      specify { expect(response).to have_http_status(:bad_request) }
      specify { expect(json[:scimType]).to eql('noTarget') }
      specify { expect(group.reload.users).to match_array([member]) }
    end

    context "when removing all members" do
      before { patch path, params: patch_body({ op: 'remove', path: 'members' }), headers: headers }

      specify { expect(group.reload.users).to be_empty }
    end

    context "when the operation has no path" do
      before { patch path, params: patch_body({ op: 'add', value: { displayName: 'Renamed', members: [{ value: new_member.to_param }] } }), headers: headers }

      specify { expect(group.reload.display_name).to eql('Renamed') }
      specify { expect(group.reload.users).to match_array([member, new_member]) }
    end

    context "when adding an unknown member" do
      before { patch path, params: patch_body({ op: 'add', path: 'members', value: [{ value: SecureRandom.uuid }] }), headers: headers }

      specify { expect(response).to have_http_status(:bad_request) }
      specify { expect(json[:scimType]).to eql('invalidValue') }
    end

    context "when a later operation fails" do
      before do
        patch path, params: patch_body(
          { op: 'replace', path: 'displayName', value: 'Renamed' },
          { op: 'add', path: 'members', value: [{ value: 'nope' }] }
        ), headers: headers
      end

      specify { expect(response).to have_http_status(:bad_request) }
      specify { expect(group.reload.display_name).not_to eql('Renamed') }
    end

    context "when removing the displayName" do
      before { patch path, params: patch_body({ op: 'remove', path: 'displayName' }), headers: headers }

      specify { expect(json[:scimType]).to eql('mutability') }
    end

    context "when patching an unknown attribute" do
      before { patch path, params: patch_body({ op: 'replace', path: 'color', value: 'red' }), headers: headers }

      specify { expect(json[:scimType]).to eql('invalidPath') }
    end

    context "when the group does not exist" do
      before { patch "/scim/v2/Groups/#{SecureRandom.uuid}", params: patch_body({ op: 'replace', path: 'displayName', value: 'x' }), headers: headers }

      specify { expect(response).to have_http_status(:not_found) }
    end
  end

  describe "DELETE /scim/v2/Groups/:id" do
    context "when the group exists" do
      before { delete "/scim/v2/Groups/#{group.to_param}", headers: headers }

      specify { expect(response).to have_http_status(:no_content) }
      specify { expect(Group.exists?(group.id)).to be(false) }
      specify { expect(User.exists?(member.id)).to be(true) }
    end

    context "when the group does not exist" do
      before { delete "/scim/v2/Groups/#{SecureRandom.uuid}", headers: headers }

      specify { expect(response).to have_http_status(:not_found) }
    end
  end

  describe "GET /scim/v2/Users/:id" do
    before { get "/scim/v2/Users/#{member.to_param}", headers: headers }

    it 'lists the groups of the user' do
      expect(json[:groups]).to eql([{ value: group.to_param, '$ref': scim_v2_group_url(group), display: group.display_name, type: 'direct' }])
    end
  end
end
