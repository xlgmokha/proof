# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User do
  describe "#sessions" do
    subject { create(:user) }

    let!(:user_session) { create(:user_session, user: subject) }

    specify { expect(subject.sessions).to match_array([user_session]) }
  end

  describe ".scim_filter_for" do
    subject { described_class }

    let!(:users) { create_list(:user, 10) }
    let(:random_user) { users.sample }
    let(:parser) { Scim::Kit::V2::Filter.new }

    def tree_for(filter)
      parser.parse(filter)
    end

    specify do
      results = subject.scim_filter_for(tree_for("userName pr"))
      expect(results.to_sql).to eql(subject.where.not(email: nil).to_sql)
      expect(results).to match_array(users)
    end

    pending do
      results = subject.scim_filter_for(tree_for("userName pr and not (userName eq \"#{random_user.email}\")"))
      expect(results).to match_array(users - [random_user])
    end

    specify do
      results = subject.scim_filter_for(tree_for("userName eq \"#{random_user.email}\""))
      expect(results).to match_array([random_user])
    end

    specify do
      results = subject.scim_filter_for(tree_for("userName ne \"#{random_user.email}\""))
      expect(results.pluck(:email)).not_to include(random_user.email)
    end

    specify do
      results = subject.scim_filter_for(tree_for("userName co \"#{random_user.email[1..-2]}\""))
      expect(results).to match_array([random_user])
    end

    specify do
      results = subject.scim_filter_for(tree_for("userName sw \"#{random_user.email[0..3]}\""))
      expect(results).to match_array([random_user])
    end

    specify do
      results = subject.scim_filter_for(tree_for("userName ew \"#{random_user.email[-8..-1]}\""))
      expect(results).to match_array([random_user])
    end

    specify do
      freeze_time
      random_user.update!(updated_at: 10.minutes.from_now)

      results = subject.scim_filter_for(tree_for("meta.lastModified gt \"#{Time.now.iso8601}\""))
      expect(results).to match_array([random_user])
    end

    specify do
      freeze_time
      random_user.update!(updated_at: 10.minutes.from_now)

      results = subject.scim_filter_for(tree_for("meta.lastModified ge \"#{random_user.updated_at.iso8601}\""))
      expect(results).to match_array([random_user])
    end

    specify do
      freeze_time
      random_user.update!(updated_at: 10.minutes.from_now)

      results = subject.scim_filter_for(tree_for("meta.lastModified lt \"#{Time.now.iso8601}\""))
      expect(results).to match_array(users - [random_user])
    end

    specify do
      freeze_time
      random_user.update!(updated_at: 10.minutes.ago)

      results = subject.scim_filter_for(tree_for("meta.lastModified le \"#{random_user.updated_at.iso8601}\""))
      expect(results).to match_array([random_user])
    end

    context "when searching for condition a OR condition b" do
      let(:first_user) { users.sample }
      let(:second_user) { users.sample }
      let(:results) { described_class.scim_filter_for(tree_for(%(userName eq "#{first_user.email}" or userName eq "#{second_user.email}"))) }

      specify { expect(results.pluck(:email)).to match_array([first_user.email, second_user.email]) }
    end

    context "when searching for condition a AND condition b" do
      let(:first_user) { users.sample }
      let(:second_user) { users.sample }
      let(:results) { described_class.scim_filter_for(tree_for(%(meta.lastModified gt "#{10.minutes.from_now.iso8601}" and meta.lastModified lt "#{15.minutes.from_now.iso8601}"))) }

      before do
        freeze_time
        first_user.update!(updated_at: 11.minutes.from_now)
        second_user.update!(updated_at: 12.minutes.from_now)
      end

      specify { expect(results).to match_array([first_user, second_user]) }
    end
  end
end
