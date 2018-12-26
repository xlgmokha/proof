# frozen_string_literal: true

module My
  class SessionsController < ApplicationController
    def index
      @sessions = current_user.sessions.active.order(:accessed_at)
    end

    def destroy
      current_user.sessions.find(params[:id]).destroy
      redirect_to my_sessions_path, notice: t('.success')
    end
  end
end
