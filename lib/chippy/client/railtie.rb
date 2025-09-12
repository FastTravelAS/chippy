module Chippy
  module Client
    if defined?(Rails::Railtie)
      class Railtie < Rails::Railtie
        config.chippy = ActiveSupport::OrderedOptions.new

        initializer "chippy.configure", after: :load_config_initializers do |app|
          Chippy::Client::RedisConsumer.configure do |config|
            config.queue_name = app.config.chippy.queue_name || app.config.chippy[:queue_name] || "chippy:readings"
            config.enabled = app.config.chippy.enabled.nil? ? (app.config.chippy[:enabled] || false) : app.config.chippy.enabled
            config.message_handler = app.config.chippy.message_handler || app.config.chippy[:message_handler]
          end
        end

        config.after_initialize do |_app|
          unless defined?(Rails::Console) || File.basename($0) == "rake" || Rails.env.test?
            if Chippy::Client::RedisConsumer.enabled
              Thread.new do
                Rails.application.executor.wrap do
                  Chippy::Client::RedisConsumer.new(
                    Chippy::Client::RedisConsumer.queue_name,
                    &Chippy::Client::RedisConsumer.message_handler
                  ).listen.join
                end
              end
            end
          end
        end
      end
    end
  end
end
