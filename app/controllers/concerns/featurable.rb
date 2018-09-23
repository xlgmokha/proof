# frozen_string_literal: true

module Featurable
  extend ActiveSupport::Concern

  included do
    helper_method :feature_enabled?
  end

  class_methods do
    def require_feature(features, options = {})
      before_action(options) do
        missing_feature = Array(features).any? { |x| feature_disabled?(x) }
        render plain: "Forbidden", status: :forbidden if missing_feature
      end
    end
  end

  def feature_enabled?(feature)
    Current.user&.feature_enabled?(feature) || Flipper.enabled?(feature.to_sym)
  end

  def feature_disabled?(feature)
    !feature_enabled?(feature)
  end
end
