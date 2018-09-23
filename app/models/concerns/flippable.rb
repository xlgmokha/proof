# frozen_string_literal: true

module Flippable
  extend ActiveSupport::Concern

  def flipper_id
    "#{self.class.name};#{to_param}"
  end

  def enable_feature(feature)
    Flipper.enable_actor(feature.to_sym, self) unless feature_enabled?(feature)
  end

  def disable_feature(feature)
    Flipper.disable_actor(feature.to_sym, self)
  end

  def feature_enabled?(feature)
    Flipper.enabled?(feature.to_sym, self)
  end
end
