RSpec.configure do |config|
  config.include(Module.new do
    def http_login(user)
      post '/session', params: { user: { email: user.email, password: user.password } }
    end
  end)
end
