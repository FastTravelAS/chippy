# stdlib
require "logger"
require "optparse"

# dependencies
require "redis"
require "active_support/tagged_logging"
require "active_support/isolated_execution_state"
require "active_support/core_ext/integer"
require "sentry-ruby"

require "chippy/logger_helper"
require "chippy/cli"
require "chippy/connection"
require "chippy/connection_status"
require "chippy/handshake"
require "chippy/handshake_messages"
require "chippy/message"
require "chippy/message/body"
require "chippy/message/header"
require "chippy/message_handler"
require "chippy/redis_producer"
require "chippy/server"
require "chippy/version"

require "chippy/client/redis_consumer"
require "chippy/client/railtie" if defined?(Rails)

# Chippy is the main module containing all the classes and submodules
# required to handle communication with transceivers (hereby "Chippy device(s)").
module Chippy
  class << self
    def start(options = {})
      port, hostname, concurrency, redis_url, redis_list = options.values_at(:port, :hostname, :concurrency, :redis_url, :redis_list)

      test_redis_connection(redis_url)

      Chippy.setup_producer(redis_list, url: redis_url)
      Chippy::Server.new(port: port, hostname: hostname, concurrency: concurrency).run
    end

    attr_writer :logger
    attr_reader :producer

    def logger
      @logger ||= ActiveSupport::TaggedLogging.new(::Logger.new($stdout)).tap do |logger|
        logger.tagged("Chippy")
      end
    end

    def setup_producer(list_name, redis_options = {})
      @producer = RedisProducer.new(list_name, redis_options)
    end

    def test_redis_connection(redis_url)
      redis_test = Redis.new(url: redis_url)
      begin
        redis_test.ping
      rescue Redis::CannotConnectError
        puts "Cannot connect to Redis at '#{redis_url}'. Please check your Redis connection string."
        exit 1
      end
    end
  end

  # MalformedMessageError is a custom error class that represents a message with
  # incorrect structure or content, making it impossible to process.
  class MalformedMessageError < StandardError
    attr_reader :remaining_data_length

    def initialize(message = nil, remaining_data_length: nil)
      super(message)
      @remaining_data_length = remaining_data_length
    end
  end

  # MessageError is a custom error class that represents an issue with a message,
  # such as invalid data or unexpected content.
  class MessageError < StandardError; end

  # DeviceError is a custom error class that represents an error in the Chippy device,
  # with a specific error message indicating the type of error.
  class DeviceError < StandardError
    attr_reader :errors

    def initialize(errors)
      @errors = errors
      super("Device errors: #{errors.join(", ")}")
    end
  end

  # HandshakeError is a custom error class that represents a problem that occurs
  # during the handshake process with a Chippy device.
  class HandshakeError < StandardError; end
end
