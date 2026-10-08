# frozen_string_literal: true

require 'rails_helper'

describe "authorizing an OAuth client in a browser", :js do
  let(:user) { create(:user) }
  let(:state) { SecureRandom.uuid }
  # Any logged-in page of the test server will do as the client callback.
  let(:callback) { "#{Capybara.current_session.server_url}/my/dashboard" }
  let(:client) { create(:client, redirect_uris: [callback]) }

  it 'redirects to the client with an authorization code' do
    visit new_session_path
    fill_in "user_email", with: user.email
    fill_in "user_password", with: user.password
    click_button I18n.t('sessions.new.login')
    expect(page).to have_content('Dashboard')

    visit oauth_authorizations_path(
      client_id: client.to_param, response_type: 'code', redirect_uri: callback, state: state,
      code_challenge: PkceHelpers::PKCE_CHALLENGE, code_challenge_method: 'S256'
    )
    click_button I18n.t('oauth.authorizations.show.authorize')

    expect(page).to have_current_path(%r{/my/dashboard\?code=.+&state=#{state}&iss=}, url: true)
  end
end
