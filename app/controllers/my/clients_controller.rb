# frozen_string_literal: true

module My
  class ClientsController < ApplicationController
    def index; end

    def new
      @client = Client.new
    end

    def create
      Client.create!(secure_params)
      redirect_to my_clients_path, notice: "Client successfully created!"
    end

    private

    def secure_params
      params.require(:client).permit(:name, :secret, :redirect_uri)
    end
  end
end
