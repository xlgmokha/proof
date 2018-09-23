# frozen_string_literal: true

module My
  class AuditsController < ApplicationController
    def index
      @audits = Audited::Audit.all
    end
  end
end
