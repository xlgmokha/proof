# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "/scim/v2/Bulk" do
  include_context 'with scim authentication'

  let(:bulk_schema) { Scim::Kit::V2::Messages::BULK_REQUEST }
  let(:operations) { json[:Operations] }

  def bulk_body(*operations, **extra)
    { schemas: [bulk_schema], Operations: operations }.merge(extra).to_json
  end

  def user_data(email = generate(:email))
    { schemas: [Scim::Kit::V2::Schemas::USER], userName: email, locale: 'en', timezone: 'Etc/UTC' }
  end

  describe "POST /scim/v2/Bulk" do
    context "when creating resources" do
      let(:email) { generate(:email) }

      before do
        post '/scim/v2/Bulk', headers: headers, params: bulk_body(
          { method: 'POST', path: '/Users', bulkId: 'u1', data: user_data(email) },
          { method: 'POST', path: '/Groups', bulkId: 'g1', data: { displayName: 'Bulk group', members: [{ value: 'bulkId:u1' }] } }
        )
      end

      specify { expect(response).to have_http_status(:ok) }
      specify { expect(response.headers['Content-Type']).to eql('application/scim+json') }
      specify { expect(json[:schemas]).to match_array([Scim::Kit::V2::Messages::BULK_RESPONSE]) }
      specify { expect(operations.pluck(:status)).to eql(%w[201 201]) }
      specify { expect(operations.pluck(:bulkId)).to eql(%w[u1 g1]) }
      specify { expect(operations.pluck(:method)).to eql(%w[POST POST]) }
      specify { expect(operations[0][:location]).to eql(scim_v2_user_url(User.find_by!(email: email))) }
      specify { expect(operations[1][:location]).to eql(scim_v2_group_url(Group.find_by!(display_name: 'Bulk group'))) }
      specify { expect(Group.find_by!(display_name: 'Bulk group').users).to match_array([User.find_by!(email: email)]) }
    end

    context "when updating, patching and deleting resources" do
      let(:target) { create(:user, locale: 'en') }
      let(:doomed) { create(:user) }
      let(:group) { create(:group) }

      before do
        post '/scim/v2/Bulk', headers: headers, params: bulk_body(
          { method: 'PUT', path: "/Users/#{target.to_param}", data: user_data('put@example.com') },
          { method: 'PATCH', path: "/Users/#{target.to_param}", data: { schemas: [patch_schema], Operations: [{ op: 'replace', path: 'locale', value: 'ja' }] } },
          { method: 'PATCH', path: "/Groups/#{group.to_param}", data: { schemas: [patch_schema], Operations: [{ op: 'add', path: 'members', value: [{ value: target.to_param }] }] } },
          { method: 'DELETE', path: "/Users/#{doomed.to_param}" }
        )
      end

      specify { expect(operations.pluck(:status)).to eql(%w[200 200 200 204]) }
      specify { expect(operations[0][:location]).to eql(scim_v2_user_url(target)) }
      specify { expect(operations[3]).not_to include(:location) }
      specify { expect(target.reload.email).to eql('put@example.com') }
      specify { expect(target.reload.locale).to eql('ja') }
      specify { expect(group.reload.users).to match_array([target]) }
      specify { expect(User.exists?(doomed.id)).to be(false) }
    end

    context "when an operation fails" do
      let(:existing) { create(:user) }

      before do
        post '/scim/v2/Bulk', headers: headers, params: bulk_body(
          { method: 'POST', path: '/Users', bulkId: 'ok', data: user_data },
          { method: 'POST', path: '/Users', bulkId: 'dup', data: user_data(existing.email) },
          { method: 'POST', path: '/Users', bulkId: 'bad', data: user_data.merge(locale: 'xx') },
          { method: 'DELETE', path: "/Users/#{SecureRandom.uuid}" }
        )
      end

      specify { expect(response).to have_http_status(:ok) }
      specify { expect(operations.pluck(:status)).to eql(%w[201 409 400 404]) }
      specify { expect(operations[1][:response][:scimType]).to eql('uniqueness') }
      specify { expect(operations[1][:response][:status]).to eql('409') }
      specify { expect(operations[2][:response][:scimType]).to eql('invalidValue') }
      specify { expect(operations[3][:response][:schemas]).to eql([Scim::Kit::V2::Messages::ERROR]) }
      specify { expect(operations[0]).not_to include(:response) }
    end

    context "when failOnErrors is reached" do
      before do
        post '/scim/v2/Bulk', headers: headers, params: bulk_body(
          { method: 'DELETE', path: "/Users/#{SecureRandom.uuid}" },
          { method: 'POST', path: '/Users', bulkId: 'never', data: user_data('never@example.com') },
          failOnErrors: 1
        )
      end

      specify { expect(operations.size).to be(1) }
      specify { expect(User.exists?(email: 'never@example.com')).to be(false) }
    end

    context "when a failed operation partially wrote data" do
      before do
        post '/scim/v2/Bulk', headers: headers, params: bulk_body(
          { method: 'POST', path: '/Groups', bulkId: 'g', data: { displayName: 'Partial', members: [{ value: SecureRandom.uuid }] } }
        )
      end

      specify { expect(operations[0][:status]).to eql('400') }
      specify { expect(Group.exists?(display_name: 'Partial')).to be(false) }
    end

    context "when a bulkId cannot be resolved" do
      before do
        post '/scim/v2/Bulk', headers: headers, params: bulk_body(
          { method: 'POST', path: '/Groups', bulkId: 'g', data: { displayName: 'Dangling', members: [{ value: 'bulkId:missing' }] } }
        )
      end

      specify { expect(operations[0][:status]).to eql('409') }
      specify { expect(Group.exists?(display_name: 'Dangling')).to be(false) }
    end

    context "when a bulkId is used in a path" do
      before do
        post '/scim/v2/Bulk', headers: headers, params: bulk_body(
          { method: 'POST', path: '/Users', bulkId: 'u1', data: user_data('first@example.com') },
          { method: 'PATCH', path: '/Users/bulkId:u1', data: { schemas: [patch_schema], Operations: [{ op: 'replace', path: 'locale', value: 'ja' }] } }
        )
      end

      specify { expect(operations.pluck(:status)).to eql(%w[201 200]) }
      specify { expect(User.find_by!(email: 'first@example.com').locale).to eql('ja') }
    end

    context "when a POST has no bulkId" do
      before { post '/scim/v2/Bulk', headers: headers, params: bulk_body({ method: 'POST', path: '/Users', data: user_data }) }

      specify { expect(operations[0][:status]).to eql('400') }
    end

    context "when the same bulkId is used twice" do
      before do
        post '/scim/v2/Bulk', headers: headers, params: bulk_body(
          { method: 'POST', path: '/Users', bulkId: 'a', data: user_data },
          { method: 'POST', path: '/Users', bulkId: 'a', data: user_data }
        )
      end

      specify { expect(operations.pluck(:status)).to eql(%w[201 400]) }
    end

    context "when the method or path is unsupported" do
      before do
        post '/scim/v2/Bulk', headers: headers, params: bulk_body(
          { method: 'GET', path: '/Users' },
          { method: 'POST', path: '/Widgets', bulkId: 'w', data: {} },
          { method: 'PUT', path: '/Users', data: user_data }
        )
      end

      specify { expect(operations.pluck(:status)).to eql(%w[400 400 400]) }
    end

    context "when there are too many operations" do
      before do
        operations = Array.new(Scim::Bulk::MAX_OPERATIONS + 1) { |i| { method: 'DELETE', path: "/Users/#{i}" } }
        post '/scim/v2/Bulk', headers: headers, params: bulk_body(*operations)
      end

      specify { expect(response).to have_http_status(:content_too_large) }
      specify { expect(json[:scimType]).to eql('tooMany') }
    end

    context "when the payload is too large" do
      before do
        stub_const('Scim::Bulk::MAX_PAYLOAD_SIZE', 10)
        post '/scim/v2/Bulk', headers: headers, params: bulk_body({ method: 'DELETE', path: '/Users/1' })
      end

      specify { expect(response).to have_http_status(:content_too_large) }
    end

    context "when the BulkRequest schema is missing" do
      before { post '/scim/v2/Bulk', headers: headers, params: { Operations: [{ method: 'DELETE', path: '/Users/1' }] }.to_json }

      specify { expect(response).to have_http_status(:bad_request) }
      specify { expect(json[:scimType]).to eql('invalidSyntax') }
    end

    context "when there are no operations" do
      before { post '/scim/v2/Bulk', headers: headers, params: bulk_body }

      specify { expect(response).to have_http_status(:bad_request) }
    end

    context "when not authenticated" do
      before { post '/scim/v2/Bulk', headers: headers.merge('Authorization' => 'Bearer nope'), params: bulk_body({ method: 'POST', path: '/Users', bulkId: 'a', data: user_data }) }

      specify { expect(response).to have_http_status(:unauthorized) }
    end
  end
end
