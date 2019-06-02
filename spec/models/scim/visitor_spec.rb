# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ::Scim::Visitor do
  subject { described_class.new(User, SCIM::User::ATTRIBUTES) }

  describe "#visit" do
    let!(:users) { create_list(:user, 10) }
    let(:random_user) { users.sample }
    let(:parser) { Scim::Kit::V2::Filter.new }

    def tree_for(filter)
      parser.parse(filter)
    end

    specify do
      results = described_class.result_for("userName pr")
      expect(results.to_sql).to eql(User.where.not(email: nil).to_sql)
      expect(results).to match_array(users)
    end

    pending do
      results = Scim::Node.parse("userName pr and not (userName eq \"#{random_user.email}\")").accept(subject)
      expect(results).to match_array(users - [random_user])
    end

    specify do
      results = Scim::Node.parse("userName eq \"#{random_user.email}\"").accept(subject)
      expect(results).to match_array([random_user])
    end

    specify do
      results = Scim::Node.parse("userName ne \"#{random_user.email}\"").accept(subject)
      expect(results.pluck(:email)).not_to include(random_user.email)
    end

    specify do
      results = Scim::Node.parse("userName co \"#{random_user.email[1..-2]}\"").accept(subject)
      expect(results).to match_array([random_user])
    end

    specify do
      results = Scim::Node.parse("userName sw \"#{random_user.email[0..3]}\"").accept(subject)
      expect(results).to match_array([random_user])
    end

    specify do
      results = Scim::Node.parse("userName ew \"#{random_user.email[-8..-1]}\"").accept(subject)
      expect(results).to match_array([random_user])
    end

    specify do
      freeze_time
      random_user.update!(updated_at: 10.minutes.from_now)

      results = Scim::Node.parse("meta.lastModified gt \"#{Time.now.iso8601}\"").accept(subject)
      expect(results).to match_array([random_user])
    end

    specify do
      freeze_time
      random_user.update!(updated_at: 10.minutes.from_now)

      results = Scim::Node.parse("meta.lastModified ge \"#{random_user.updated_at.iso8601}\"").accept(subject)
      expect(results).to match_array([random_user])
    end

    specify do
      freeze_time
      random_user.update!(updated_at: 10.minutes.from_now)

      results = Scim::Node.parse("meta.lastModified lt \"#{Time.now.iso8601}\"").accept(subject)
      expect(results).to match_array(users - [random_user])
    end

    specify do
      freeze_time
      random_user.update!(updated_at: 10.minutes.ago)

      results = Scim::Node.parse("meta.lastModified le \"#{random_user.updated_at.iso8601}\"").accept(subject)
      expect(results).to match_array([random_user])
    end

    context "when searching for condition a OR condition b" do
      let(:first_user) { users.sample }
      let(:second_user) { users.sample }
      let(:results) { Scim::Node.parse(%(userName eq "#{first_user.email}" or userName eq "#{second_user.email}")).accept(subject) }

      specify { expect(results.pluck(:email)).to match_array([first_user.email, second_user.email]) }
    end

    context "when searching for condition a AND condition b" do
      let(:first_user) { users.sample }
      let(:second_user) { users.sample }
      let(:results) { Scim::Node.parse(%(meta.lastModified gt "#{10.minutes.from_now.iso8601}" and meta.lastModified lt "#{15.minutes.from_now.iso8601}")).accept(subject) }

      before do
        freeze_time
        first_user.update!(updated_at: 11.minutes.from_now)
        second_user.update!(updated_at: 12.minutes.from_now)
      end

      specify { expect(results).to match_array([first_user, second_user]) }
    end
  end
end
