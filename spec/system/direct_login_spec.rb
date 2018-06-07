require 'rails_helper'

describe "when logging in directly in to the application", js: true do
  describe "when tfa is disabled", js: true do
    let(:user) { create(:user) }

    it 'redirects the user to the dashboard' do
      visit root_path
      fill_in "user_email", with: user.email
      fill_in "user_password", with: user.password
      click_button I18n.t('sessions.new.login')

      expect(page).to have_content('Dashboard')
    end
  end

  describe "when TFA is enabled", js: true do
    let(:user) { create(:user, tfa_secret: ::ROTP::Base32.random_base32) }

    it 'prompts for a TOTP code then redirect to the dashboard' do
      pending
      visit root_path
      fill_in "user_email", with: user.email
      fill_in "user_password", with: user.password
      click_button I18n.t('sessions.new.login')

      fill_in "totp", with: user.tfa.current_totp

      expect(page).to have_content('Dashboard')
    end
  end
end
