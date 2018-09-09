RSpec.configure do |config|
  config.include ActiveSupport::Testing::TimeHelpers
  config.after :each do |example|
    travel_back
  end
  config.include(Module.new do
    def freeze_time
      travel_to 1.second.from_now
    end
  end)
end
