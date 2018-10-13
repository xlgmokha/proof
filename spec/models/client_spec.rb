require 'rails_helper'

RSpec.describe Client do
  describe "#validation" do
    specify { expect(build(:client)).to be_valid }
    specify { expect(build(:client, redirect_uri: nil)).to be_invalid }
    specify { expect(build(:client, redirect_uri: '<script>alert("hi")</script>')).to be_invalid }
    specify { expect(build(:client, redirect_uri: 'invalid')).to be_invalid }
    specify { expect(build(:client, uuid: nil)).to be_invalid }
    specify { expect(build(:client, uuid: 'invalid')).to be_invalid }
    specify { expect(build(:client, name: nil)).to be_invalid }
  end
end
