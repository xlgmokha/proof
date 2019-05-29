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
    let(:random_user) { users.sample }
    let(:parser) { Scim::Kit::V2::Filter.new }

    def tree_for(filter)
      parser.parse(filter)
    end

    specify do
      results = User.scim_filter_for(tree_for("userName eq \"#{random_user.email}\""))
      expect(results).to match_array([random_user])
    end

    specify do
      results = User.scim_filter_for(tree_for("userName ne \"#{random_user.email}\""))
      expect(results.pluck(:email)).not_to include(random_user.email)
    end

    specify do
      results = User.scim_filter_for(tree_for("userName co \"#{random_user.email[1..3]}\""))
      expect(results).to match_array([random_user])
    end

    specify do
      results = User.scim_filter_for(tree_for("userName sw \"#{random_user.email[0..3]}\""))
      expect(results).to match_array([random_user])
    end

    specify do
      results = User.scim_filter_for(tree_for("userName ew \"#{random_user.email[-5..-1]}\""))
      expect(results).to match_array([random_user])
    end

    specify do
      freeze_time
      random_user.update!(updated_at: 10.minutes.from_now)

      results = User.scim_filter_for(tree_for("meta.lastModified gt \"#{Time.now.iso8601}\""))
      expect(results).to match_array([random_user])
    end

    specify do
      first_user = users.sample
      second_user = users.sample
      results = User.scim_filter_for(
        tree_for(%(userName eq "#{first_user.email}" or userName eq "#{second_user.email}"))
      )
      expect(results.pluck(:email)).to match_array([first_user.email, second_user.email])
    end
  end
end
