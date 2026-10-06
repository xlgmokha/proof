# frozen_string_literal: true

require 'rails_helper'

# RFC 8628: OAuth 2.0 Device Authorization Grant
RSpec.describe 'device authorization grant' do
  let(:grant_type) { 'urn:ietf:params:oauth:grant-type:device_code' }
  let(:client) { create(:client, grant_types: GrantTypes::ALL) }
  let(:credentials) { ActionController::HttpAuthentication::Basic.encode_credentials(client.to_param, client.password) }
  let(:headers) { { 'Authorization' => credentials } }

  def start(positional = {}, headers: self.headers, **extra)
    post '/oauth/device_authorization', params: positional.merge(extra), headers: headers
  end

  describe 'POST /oauth/device_authorization' do
    context 'when the client is authenticated' do
      before { start(scope: 'admin') }

      # Section 3.2
      specify { expect(response).to have_http_status(:ok) }
      specify { expect(response.content_type).to start_with('application/json') }
      specify { expect(response.headers['Cache-Control']).to include('no-store') }
      specify { expect(json[:device_code]).to be_present }
      specify { expect(json[:user_code]).to match(/\A[BCDFGHJKLMNPQRSTVWXZ]{4}-[BCDFGHJKLMNPQRSTVWXZ]{4}\z/) }
      specify { expect(json[:verification_uri]).to eql('http://www.example.com/oauth/device') }
      specify { expect(json[:verification_uri_complete]).to eql("http://www.example.com/oauth/device?user_code=#{json[:user_code]}") }
      specify { expect(json[:expires_in]).to eql(600) }
      specify { expect(json[:interval]).to eql(5) }

      it 'does not store the device code' do
        expect(DeviceAuthorization.pluck(:device_code_digest)).not_to include(json[:device_code])
        expect(DeviceAuthorization.last.scope).to eql('admin')
      end
    end

    context 'when the client is not authenticated' do
      before { start({}, headers: {}) }

      specify { expect(response).to have_http_status(:unauthorized) }
      specify { expect(json[:error]).to eql('invalid_client') }
    end

    context 'when the client is public' do
      let(:client) { create(:client, :public, grant_types: %w[authorization_code urn:ietf:params:oauth:grant-type:device_code]) }

      before { start({ client_id: client.to_param }, headers: {}) }

      specify { expect(response).to have_http_status(:ok) }
    end

    context 'when the client may not use the grant' do
      let(:client) { create(:client, grant_types: %w[authorization_code]) }

      before { start }

      specify { expect(response).to have_http_status(:bad_request) }
      specify { expect(json[:error]).to eql('unauthorized_client') }
    end

    context 'when the scope is not supported' do
      before { start(scope: 'nope') }

      specify { expect(json[:error]).to eql('invalid_scope') }
    end

    it 'does not hand out the same user code twice' do
      codes = Array.new(5) { start && JSON.parse(response.body)['user_code'] }
      expect(codes.uniq.size).to eql(5)
    end
  end

  describe 'verification by the user' do
    let(:user) { create(:user) }
    let(:request) { DeviceAuthorization.last }

    before do
      start(scope: 'admin')
      @user_code = JSON.parse(response.body)['user_code']
      http_login(user)
    end

    context 'when the user opens the verification uri' do
      before { get '/oauth/device' }

      specify { expect(response).to have_http_status(:ok) }
    end

    context 'when the user opens the complete verification uri' do
      before { get '/oauth/device', params: { user_code: @user_code } }

      specify { expect(response.body).to include(CGI.escapeHTML(client.name)) }
      specify { expect(response.body).to include(@user_code) }
    end

    context 'when the user types the code loosely' do
      before { post '/oauth/device', params: { user_code: @user_code.downcase.delete('-') } }

      # Section 6.1: the comparison ignores case and punctuation.
      specify { expect(response.body).to include(CGI.escapeHTML(client.name)) }
    end

    context 'when the user approves' do
      before { post '/oauth/device', params: { user_code: @user_code, approve: '1' } }

      specify { expect(response).to have_http_status(:ok) }
      specify { expect(request).to be_approved }
      specify { expect(request.user).to eql(user) }
    end

    context 'when the user denies' do
      before { post '/oauth/device', params: { user_code: @user_code, deny: '1' } }

      specify { expect(request).to be_denied }
    end

    context 'when the code is unknown' do
      before { post '/oauth/device', params: { user_code: 'BBBB-BBBB', approve: '1' } }

      specify { expect(response).to have_http_status(:unprocessable_entity) }
      specify { expect(request).to be_pending }
    end

    context 'when the code has expired' do
      before do
        request.update!(expires_at: 1.second.ago)
        post '/oauth/device', params: { user_code: @user_code, approve: '1' }
      end

      specify { expect(response).to have_http_status(:unprocessable_entity) }
      specify { expect(request).to be_pending }
    end

    context 'when the code was already used' do
      before do
        post '/oauth/device', params: { user_code: @user_code, approve: '1' }
        post '/oauth/device', params: { user_code: @user_code, deny: '1' }
      end

      specify { expect(response).to have_http_status(:unprocessable_entity) }
      specify { expect(request).to be_approved }
    end
  end

  describe 'verification when not logged in' do
    before do
      start
      get '/oauth/device'
    end

    specify { expect(response).to redirect_to(new_session_path) }
  end

  describe 'POST /oauth/tokens' do
    let(:user) { create(:user) }
    let(:request) { DeviceAuthorization.last }
    let(:poll) { { grant_type: grant_type, device_code: @device_code } }

    before do
      start(scope: 'admin')
      @device_code = JSON.parse(response.body)['device_code']
    end

    def poll!(params = poll, headers: self.headers)
      @json = nil
      post '/oauth/tokens', params: params, headers: headers
    end

    context 'when the user has not acted yet' do
      before { poll! }

      # Section 3.5
      specify { expect(response).to have_http_status(:bad_request) }
      specify { expect(json[:error]).to eql('authorization_pending') }
    end

    context 'when polling faster than the interval' do
      before do
        poll!
        @interval = request.reload.interval
        poll!
      end

      specify { expect(json[:error]).to eql('slow_down') }
      specify { expect(request.reload.interval).to eql(@interval + 5) }
    end

    context 'when polling at the interval' do
      before do
        poll!
        request.update!(last_polled_at: 6.seconds.ago)
        poll!
      end

      specify { expect(json[:error]).to eql('authorization_pending') }
    end

    context 'when the user approved' do
      before do
        request.approve!(user)
        poll!
      end

      specify { expect(response).to have_http_status(:ok) }
      specify { expect(response.headers['Cache-Control']).to include('no-store') }
      specify { expect(json[:access_token]).to be_present }
      specify { expect(json[:refresh_token]).to be_present }
      specify { expect(json[:token_type]).to eql('Bearer') }
      specify { expect(json[:scope]).to eql('admin') }
      specify { expect(Token.claims_for(json[:access_token])[:sub]).to eql(user.to_param) }
      specify { expect(Token.claims_for(json[:access_token])[:client_id]).to eql(client.to_param) }

      it 'can only be redeemed once' do
        request.update!(last_polled_at: nil) if request.persisted?
        poll!
        expect(json[:error]).to eql('invalid_grant')
      end
    end

    context 'when the user denied' do
      before do
        request.deny!
        poll!
      end

      specify { expect(json[:error]).to eql('access_denied') }
    end

    context 'when the code has expired' do
      before do
        request.update!(expires_at: 1.second.ago)
        poll!
      end

      specify { expect(json[:error]).to eql('expired_token') }
    end

    context 'when the device code is unknown' do
      before { poll!(poll.merge(device_code: 'nope')) }

      specify { expect(json[:error]).to eql('invalid_grant') }
    end

    context 'when the device code is missing' do
      before { poll!(poll.except(:device_code)) }

      specify { expect(json[:error]).to eql('invalid_request') }
    end

    context 'when another client presents the device code' do
      let(:other) { create(:client, grant_types: GrantTypes::ALL) }
      let(:other_credentials) { ActionController::HttpAuthentication::Basic.encode_credentials(other.to_param, other.password) }

      before do
        request.approve!(user)
        poll!(poll, headers: { 'Authorization' => other_credentials })
      end

      specify { expect(json[:error]).to eql('invalid_grant') }
      specify { expect(DeviceAuthorization.count).to be(1) }
    end

    context 'when the client may not use the grant' do
      before do
        client.update_columns(grant_types: %w[authorization_code])
        poll!
      end

      specify { expect(json[:error]).to eql('unauthorized_client') }
    end
  end

  describe 'the metadata' do
    before { get '/.well-known/oauth-authorization-server' }

    specify { expect(json[:device_authorization_endpoint]).to eql(oauth_device_authorization_url) }
    specify { expect(json[:grant_types_supported]).to include(grant_type) }
  end
end
