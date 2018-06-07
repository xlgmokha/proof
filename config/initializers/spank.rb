# frozen_string_literal: true

container = Spank::Container.new
container.register(:user_repository) do |x|
  SCIM::UserRepository.new(x.resolve(:user_mapper))
end.as_singleton
container.register(:user_mapper) do |x|
  SCIM::UserMapper.new(x.resolve(:url_helpers))
end.as_singleton
container.register(:url_helpers) do |_container|
  Rails.application.routes.url_helpers
end

Spank::IOC.bind_to(container)
