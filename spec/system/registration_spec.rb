# frozen_string_literal: true

require 'rails_helper'

describe "when registering for an account", js: true do
  let(:email) { FFaker::Internet.email }
  let(:password) { FFaker::Internet.password }

  specify do
    visit new_registration_path
    within "form[action^='/registrations']" do
      fill_in "user_email", with: email
      fill_in "user_password", with: password
      fill_in "user_password_confirmation", with: password
      click_button I18n.t('registrations.new.register')
    end
    within "form[action^='/session']" do
      fill_in "user_email", with: email
      fill_in "user_password", with: password
      click_button I18n.t('sessions.new.login')
    end
    expect(page).to have_content(I18n.t('my.dashboards.show.title'))
  end
end
