# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationHelper do
  describe "#alert_class_for" do
    specify { expect(helper.alert_class_for(:notice)).to eql('is-success') }
    specify { expect(helper.alert_class_for('notice')).to eql('is-success') }
    specify { expect(helper.alert_class_for(:warning)).to eql('is-warning') }
    specify { expect(helper.alert_class_for(:error)).to eql('is-danger') }
    specify { expect(helper.alert_class_for(:info)).to eql('is-info') }
  end

  describe "#flash_error_messages_for" do
    context "when the item is an array of strings" do
      it 'returns the array of strings' do
        expect(helper.flash_error_messages_for(['error'])).to match_array(['error'])
      end

      context "when the item is a single string" do
        it 'returns an array of strings when' do
          expect(helper.flash_error_messages_for('error')).to match_array(['error'])
        end
      end

      context "when the item is an instance of ActiveModel::Errors" do
        let(:user_class) do
          Class.new do
            extend ActiveModel::Naming
            attr_reader :email, :password

            def read_attribute_for_validation(attr)
              send(attr)
            end

            def self.human_attribute_name(attr, _options = {})
              attr.to_s.titleize
            end

            def self.lookup_ancestors
              [self]
            end
          end
        end
        let(:user) { user_class.new }
        let(:errors) do
          errors = ActiveModel::Errors.new(user)
          errors.add(:email, 'has already been taken.')
          errors.add(:password, 'must contain at least one upper case character.')
          errors.add(:password, 'must contain at least one numeric character.')
          errors
        end

        specify do
          expect(helper.flash_error_messages_for(errors)).to match_array([
            'Email has already been taken.',
            'Password must contain at least one upper case character. Password must contain at least one numeric character.',
          ])
        end
      end
    end
  end
end
