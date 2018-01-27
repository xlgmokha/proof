$container=Spank::Container.new
$container.register(:user_repository) do |container|
  UserRepository.new(container.resolve(:user_mapper))
end.as_singleton
$container.register(:user_mapper) do |container|
  UserMapper.new(container.resolve(:url_helpers))
end.as_singleton
$container.register(:url_helpers) do |container|
  Rails.application.routes.url_helpers
end
