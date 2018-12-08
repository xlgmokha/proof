# frozen_string_literal: true

module My
  class ClientsController < ApplicationController
    def index
      @clients = Client.all
    end

    def new
      @client = Client.new
    end

    def create
      client = Client.create!(secure_params)
      notice = t(
        '.success',
        client_id: client.to_param,
        client_secret: client.password
      )
      redirect_to my_clients_path, notice: notice
    end

    private

    def secure_params
      params.require(:client).permit(:name, :password, redirect_uris: [])
    end
  end
end
