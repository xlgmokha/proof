RSpec.configure do |config|
  config.include(Module.new do
    def http_login(user, skip_mfa: false)
      post '/session', params: { user: { email: user.email, password: user.password } }
      return if skip_mfa
      mfa_login(user) if user.mfa.setup?
    end

    def mfa_login(user)
      post '/mfa', params: { mfa: { code: user.mfa.current_totp } }
    end
  end)
end
