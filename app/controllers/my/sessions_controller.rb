# frozen_string_literal: true

module My
  class SessionsController < ApplicationController
    def index
      @sessions = current_user.sessions
    end
  end
end
