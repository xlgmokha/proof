# frozen_string_literal: true

require 'rails_helper'

describe "navigating with Turbo", :js do
  let(:user) { create(:user) }

  def login
    page.driver.browser.manage.window.resize_to(1400, 900)
    visit root_path
    fill_in "user_email", with: user.email
    fill_in "user_password", with: user.password
    click_button I18n.t('sessions.new.login')
    expect(page).to have_content('Dashboard')
  end

  it 'navigates without a full page reload' do
    login
    page.execute_script("window.__turbo_marker = true")
    find('.navbar-link').hover
    click_link I18n.t('sessions.show.sessions')

    expect(page).to have_current_path(my_sessions_path)
    expect(page.evaluate_script("window.__turbo_marker")).to be(true)
  end

  it 'revokes another session and redirects back to the list' do
    login
    other = user.sessions.create!(ip: '10.0.0.1', user_agent: 'Mozilla/5.0 Firefox/120.0', accessed_at: Time.current)
    visit my_sessions_path
    expect(page).to have_content('10.0.0.1')

    find("a[href='#{my_session_path(other.to_param)}']").click

    expect(page).to have_current_path(my_sessions_path)
    expect(page).not_to have_content('10.0.0.1')
  end

  it 'renders the MFA test result inside a turbo frame' do
    login
    visit new_my_mfa_path
    fill_in "user_code", with: '000000'
    click_button I18n.t('my.mfas.new.test')

    within('turbo-frame#mfa_test_result') do
      expect(page).to have_css('.notification')
    end
    expect(page).to have_current_path(new_my_mfa_path)
  end

  it 'logs out' do
    login
    click_button I18n.t('sessions.show.logout')

    expect(page).to have_css('#user_email')
  end
end
