# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Scim::BulkIds do
  subject(:ids) { described_class.new }

  before do
    ids.reserve('abc')
    ids.bind('abc', 42)
  end

  describe '#resolve_all' do
    it 'resolves reference fields' do
      data = { 'members' => [{ 'value' => 'bulkId:abc' }], 'manager' => { '$ref' => 'bulkId:abc' } }

      expect(ids.resolve_all(data)).to eql(
        'members' => [{ 'value' => '42' }], 'manager' => { '$ref' => '42' }
      )
    end

    it 'leaves free text alone' do
      data = { 'password' => 'bulkId:abc', 'displayName' => 'bulkId:abc' }

      expect(ids.resolve_all(data)).to eql(data)
    end
  end
end
