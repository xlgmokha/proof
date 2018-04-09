require 'rails_helper'

describe "when logging in directly in to the application", js: true do
  let(:user) { create(:user) }

  it 'redirects the user to the dashboard' do
    visit root_path
    fill_in "user_email", with: user.email
    fill_in "user_password", with: user.password
    click_button I18n.t('sessions.new.login')

    expect(page).to have_content('Dashboard')
  end
end
