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
      first_user = users.sample
      second_user = users.sample
      parse_tree = tree_for(%(userName eq "#{first_user.email}" or userName eq "#{second_user.email}"))
      puts parse_tree
      results = User.scim_filter_for(parse_tree)
      puts results.to_sql
      expect(results.pluck(:email)).to match_array([first_user.email, second_user.email])
    end
  end
end
