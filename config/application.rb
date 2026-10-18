require_relative "boot"
require "rails"
require "active_model/railtie"
require "active_record/railtie"
require "action_controller/railtie"

Bundler.require(*Rails.groups)

module AdvisorClientPortal
  class Application < Rails::Application
    config.load_defaults 7.1
    config.api_only = true
    config.eager_load = false
    config.secret_key_base = ENV.fetch("SECRET_KEY_BASE") do
      raise "SECRET_KEY_BASE must be set outside development and test" unless Rails.env.local?

      "development-only-key-not-for-production"
    end
  end
end
