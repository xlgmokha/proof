require 'rails_helper'

RSpec.describe User do
  describe "#sessions" do
    subject { create(:user) }
    let!(:user_session) { create(:user_session, user: subject) }

    specify { expect(subject.sessions).to match_array([user_session]) }
  end
end
