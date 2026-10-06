# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Scim::Path do
  describe '.parse' do
    specify { expect(described_class.parse('userName').attribute).to eql('username') }
    specify { expect(described_class.parse('name.givenName').sub_attribute).to eql('givenname') }
    specify { expect(described_class.parse('emails').filter?).to be(false) }

    it 'ignores a schema prefix' do
      path = described_class.parse('urn:ietf:params:scim:schemas:core:2.0:User:userName')
      expect(path.attribute).to eql('username')
    end

    it 'parses a value filter' do
      path = described_class.parse('members[value eq "2819c223-7f76-453a-919d-413861904646"]')
      expect([path.attribute, path.filter.attribute, path.filter.value]).to eql(
        %w[members value 2819c223-7f76-453a-919d-413861904646]
      )
    end

    it 'parses a filter followed by a sub-attribute' do
      path = described_class.parse('emails[type eq "work"].value')
      expect(path.sub_attribute).to eql('value')
      expect(path.filter.value).to eql('work')
    end

    it 'parses boolean filter values' do
      expect(described_class.parse('emails[primary eq true]').filter.value).to be(true)
    end

    it 'allows colons inside a filter value' do
      path = described_class.parse('members[value eq "urn:uuid:1"]')
      expect(path.filter.value).to eql('urn:uuid:1')
    end

    ['', nil, '1abc', 'user name', 'a[', 'a[b eq ]', 'x; DROP TABLE users'].each do |raw|
      it "rejects #{raw.inspect}" do
        expect { described_class.parse(raw) }.to raise_error(Scim::Error)
      end
    end

    it 'rejects unsupported filter operators' do
      expect { described_class.parse('emails[value co "a"]') }.to raise_error(Scim::Error) { |e|
        expect(e.scim_type).to eql('invalidFilter')
      }
    end
  end

  describe '#matches?' do
    let(:path) { described_class.parse('members[value eq "1"]') }

    specify { expect(path.matches?(value: '1')).to be(true) }
    specify { expect(path.matches?('Value' => '1')).to be(true) }
    specify { expect(path.matches?(value: '2')).to be(false) }
    specify { expect(described_class.parse('members').matches?(value: '2')).to be(true) }
  end
end
