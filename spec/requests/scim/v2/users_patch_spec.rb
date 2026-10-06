# frozen_string_literal: true

require 'rails_helper'

describe 'PATCH /scim/v2/Users/:id' do
  include_context 'with scim authentication'

  let(:target) { create(:user, locale: 'en', timezone: 'Etc/UTC') }
  let(:path) { "/scim/v2/Users/#{target.to_param}" }

  context 'when replacing attributes' do
    let(:new_email) { generate(:email) }

    before do
      patch path, headers: headers, params: patch_body(
        { op: 'replace', path: 'userName', value: new_email },
        { op: 'Replace', path: 'locale', value: 'ja' },
        { op: 'add', path: 'timezone', value: 'America/Denver' }
      )
    end

    specify { expect(response).to have_http_status(:ok) }
    specify { expect(response.headers['Content-Type']).to eql('application/scim+json') }
    specify { expect(response.headers['Location']).to eql(scim_v2_user_url(target)) }
    specify { expect(json[:userName]).to eql(new_email) }
    specify { expect(json[:locale]).to eql('ja') }
    specify { expect(json[:timezone]).to eql('America/Denver') }
    specify { expect(target.reload.email).to eql(new_email) }
  end

  context 'when the operation has no path' do
    before do
      patch path, headers: headers, params: patch_body(
        { op: 'replace', value: { locale: 'ja', 'urn:ietf:params:scim:schemas:core:2.0:User:timezone': 'Asia/Tokyo' } }
      )
    end

    specify { expect(response).to have_http_status(:ok) }
    specify { expect(target.reload.locale).to eql('ja') }
    specify { expect(target.reload.timezone).to eql('Asia/Tokyo') }
  end

  context 'when using the lowercase endpoint' do
    before { patch "/scim/v2/users/#{target.to_param}", headers: headers, params: patch_body({ op: 'replace', path: 'locale', value: 'ja' }) }

    specify { expect(response).to have_http_status(:ok) }
    specify { expect(target.reload.locale).to eql('ja') }
  end

  context 'when replacing the email through emails' do
    let(:new_email) { generate(:email) }

    before do
      patch path, headers: headers, params: patch_body(
        { op: 'replace', path: 'emails', value: [{ value: 'other@example.com' }, { value: new_email, primary: true }] }
      )
    end

    specify { expect(target.reload.email).to eql(new_email) }
  end

  context 'when replacing emails.value' do
    before { patch path, headers: headers, params: patch_body({ op: 'replace', path: 'emails[primary eq true].value', value: 'new@example.com' }) }

    specify { expect(target.reload.email).to eql('new@example.com') }
  end

  context 'when changing the password of another user' do
    before { patch path, headers: headers, params: patch_body({ op: 'replace', path: 'password', value: 'secret-password' }) }

    specify { expect(response).to have_http_status(:bad_request) }
    specify { expect(json[:scimType]).to eql('mutability') }
    specify { expect(target.reload.authenticate('secret-password')).to be(false) }
  end

  context 'when changing the password of the authenticated user' do
    let(:target) { user }

    before { patch path, headers: headers, params: patch_body({ op: 'replace', path: 'password', value: 'secret-password' }) }

    specify { expect(response).to have_http_status(:ok) }
    specify { expect(json).not_to include(:password) }
    specify { expect(target.reload.authenticate('secret-password')).to be_truthy }
  end

  context 'when removing an optional attribute' do
    before { patch path, headers: headers, params: patch_body({ op: 'remove', path: 'locale' }) }

    specify { expect(response).to have_http_status(:bad_request) }
    specify { expect(json[:scimType]).to eql('invalidValue') }
  end

  context 'when removing a required attribute' do
    before { patch path, headers: headers, params: patch_body({ op: 'remove', path: 'userName' }) }

    specify { expect(response).to have_http_status(:bad_request) }
    specify { expect(json[:scimType]).to eql('mutability') }
  end

  context 'when removing without a path' do
    before { patch path, headers: headers, params: patch_body({ op: 'remove' }) }

    specify { expect(response).to have_http_status(:bad_request) }
    specify { expect(json[:scimType]).to eql('noTarget') }
  end

  context 'when patching a read-only attribute' do
    before { patch path, headers: headers, params: patch_body({ op: 'replace', path: 'id', value: SecureRandom.uuid }) }

    specify { expect(json[:scimType]).to eql('mutability') }
  end

  context 'when patching an unknown attribute' do
    before { patch path, headers: headers, params: patch_body({ op: 'replace', path: 'nickName', value: 'x' }) }

    specify { expect(response).to have_http_status(:bad_request) }
    specify { expect(json[:scimType]).to eql('invalidPath') }
  end

  context 'when the path is malformed' do
    before { patch path, headers: headers, params: patch_body({ op: 'replace', path: 'user name', value: 'x' }) }

    specify { expect(json[:scimType]).to eql('invalidPath') }
  end

  context 'when the value is invalid' do
    before { patch path, headers: headers, params: patch_body({ op: 'replace', path: 'locale', value: 'xx' }) }

    specify { expect(response).to have_http_status(:bad_request) }
    specify { expect(json[:scimType]).to eql('invalidValue') }
  end

  context 'when the value is not a string' do
    before { patch path, headers: headers, params: patch_body({ op: 'replace', path: 'userName', value: [1] }) }

    specify { expect(json[:scimType]).to eql('invalidValue') }
  end

  context 'when the email is already taken' do
    let(:other) { create(:user) }

    before { patch path, headers: headers, params: patch_body({ op: 'replace', path: 'userName', value: other.email }) }

    specify { expect(response).to have_http_status(:conflict) }
    specify { expect(json[:scimType]).to eql('uniqueness') }
  end

  context 'when a later operation fails' do
    before do
      patch path, headers: headers, params: patch_body(
        { op: 'replace', path: 'locale', value: 'ja' },
        { op: 'replace', path: 'timezone', value: 'Not/AZone' }
      )
    end

    specify { expect(response).to have_http_status(:bad_request) }
    specify { expect(target.reload.locale).to eql('en') }
  end

  context 'when the operation is not supported' do
    before { patch path, headers: headers, params: patch_body({ op: 'move', path: 'locale', value: 'ja' }) }

    specify { expect(response).to have_http_status(:bad_request) }
    specify { expect(json[:scimType]).to eql('invalidSyntax') }
  end

  context 'when the value is missing' do
    before { patch path, headers: headers, params: patch_body({ op: 'replace', path: 'locale' }) }

    specify { expect(json[:scimType]).to eql('invalidValue') }
  end

  context 'when the PatchOp schema is missing' do
    before { patch path, headers: headers, params: { Operations: [{ op: 'replace', path: 'locale', value: 'ja' }] }.to_json }

    specify { expect(response).to have_http_status(:bad_request) }
    specify { expect(json[:scimType]).to eql('invalidSyntax') }
  end

  context 'when there are no operations' do
    before { patch path, headers: headers, params: { schemas: [patch_schema], Operations: [] }.to_json }

    specify { expect(json[:scimType]).to eql('invalidSyntax') }
  end

  context 'when the user does not exist' do
    before { patch "/scim/v2/Users/#{SecureRandom.uuid}", headers: headers, params: patch_body({ op: 'replace', path: 'locale', value: 'ja' }) }

    specify { expect(response).to have_http_status(:not_found) }
  end

  context 'when not authenticated' do
    before { patch path, headers: headers.merge('Authorization' => 'Bearer nope'), params: patch_body({ op: 'replace', path: 'locale', value: 'ja' }) }

    specify { expect(response).to have_http_status(:unauthorized) }
    specify { expect(target.reload.locale).to eql('en') }
  end
end
