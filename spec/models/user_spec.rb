# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User do
  describe "#sessions" do
    subject { create(:user) }

    let!(:user_session) { create(:user_session, user: subject) }

    specify { expect(subject.sessions).to match_array([user_session]) }
  end

  describe ".scim_filter_for" do
    let!(:users) { create_list(:user, 10) }
    let(:random_user) { users.sample  }

    specify do
      expect(User.scim_filter_for(
        attribute: "userName",
        comparison_operator: "eq",
        comparison_value: "\"#{random_user.email}\""
      )).to match_array([random_user])
    end

    specify do
      expect(User.scim_filter_for(
        attribute: "userName",
        comparison_operator: "ne",
        comparison_value: "\"#{random_user.email}\""
      ).pluck(:email)).not_to include(random_user.email)
    end
  end
end
