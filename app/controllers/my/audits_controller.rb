# frozen_string_literal: true

module My
  class AuditsController < ApplicationController
    def index
      @audits = current_user.own_and_associated_audits
    end
  end
end
