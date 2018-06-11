# frozen_string_literal: true

module SCIM
  class UserRepository
    attr_reader :mapper

    def initialize(mapper)
      @mapper = mapper
    end

    def find!(id)
      mapper.map_from(User.find_by!(uuid: id))
    end

    def create!(params)
      password = SecureRandom.hex(32)
      mapper.map_from(
        User.create!(
          email: params[:userName],
          password: password
        )
      )
    end

    def update!(id, params)
      user = User.find_by!(uuid: id)
      user.update!(email: params[:userName])
      mapper.map_from(user)
    end

    def destroy!(id)
      User.find_by!(uuid: id).destroy!
    end
  end
end
