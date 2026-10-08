# frozen_string_literal: true

module Oauth
  # RFC 8628 Section 3.3: where the user enters the code shown on the device
  # and approves or denies it.
  class DevicesController < ApplicationController
    # The code is short, so guessing is limited (Section 5.1).
    rate_limit to: 10, within: 1.minute, only: %i[show create], by: -> { current_user&.id || request.remote_ip }

    # A ceiling across all users and addresses, so guesses cannot be spread out.
    rate_limit to: 300, within: 1.minute, only: %i[show create], by: -> { 'device-codes' }, name: 'global'

    before_action :refuse_when_locked, only: %i[show create]

    def show
      return if params[:user_code].blank?

      @device_authorization = DeviceAuthorization.find_pending_by_user_code(params[:user_code])
      return if @device_authorization

      FailedDeviceAttempt.record!(attempt_subject)
      flash.now[:error] = t('.unknown_code')
    end

    def create
      @device_authorization = DeviceAuthorization.find_pending_by_user_code(params[:user_code])
      return render_unknown_code unless @device_authorization

      if params[:deny].present?
        @device_authorization.deny!
        render :denied
      elsif params[:approve].present?
        @device_authorization.approve!(current_user)
        render :approved
      else
        render :show
      end
    end

    private

    def attempt_subject
      current_user&.id || request.remote_ip
    end

    def refuse_when_locked
      return if params[:user_code].blank? || !FailedDeviceAttempt.locked?(attempt_subject)

      head :too_many_requests
    end

    def render_unknown_code
      FailedDeviceAttempt.record!(attempt_subject)
      flash.now[:error] = t('oauth.devices.show.unknown_code')
      render :show, status: :unprocessable_entity
    end
  end
end
