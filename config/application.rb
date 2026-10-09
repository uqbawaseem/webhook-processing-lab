require_relative "boot"
require "rails"
require "active_record/railtie"
require "action_controller/railtie"
Bundler.require(*Rails.groups)
module WebhookLab
  class Application < Rails::Application
    config.load_defaults 8.1
    config.api_only = true
    config.autoload_lib(ignore: %w[tasks])
    config.filter_parameters += [:authorization, :token, :secret, :data, :payload]
    config.secret_key_base = ENV.fetch("SECRET_KEY_BASE") { "local-demo-only-" + "0" * 64 }
  end
end
