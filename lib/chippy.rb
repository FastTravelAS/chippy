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
require "chippy/error_handler"
require "chippy/handshake"
require "chippy/messages"
require "chippy/message"
require "chippy/message/body"
require "chippy/message/header"
require "chippy/message_handler"
require "chippy/producer"
require "chippy/server"
require "chippy/status"
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

      setup_redis(url: redis_url)
      setup_producer(redis_list)

      Chippy::Server.new(port: port, hostname: hostname, concurrency: concurrency).run
    end

    attr_writer :logger
    attr_reader :redis
    attr_reader :producer

    def logger
      logger = if ENV["CHIPPY_LOG_TO_STDOUT"] == "true" || ENV["CHIPPY_ENV"] == "test"
        Logger.new($stdout)
      else
        Logger.new("log/chippy.#{ENV.fetch("CHIPPY_ENV", "development")}.log")
      end

      @logger ||= ActiveSupport::TaggedLogging.new(logger).tap do |logger|
        logger.tagged("Chippy")
      end
    end

    def log_formatter
      @log_formatter ||= Chippy::LogFormatter.new
    end

    def setup_redis(redis_options = {})
      @redis = Redis.new(redis_options)
    end

    def setup_producer(list_name, redis = @redis)
      @producer = Producer.new(list_name, redis)
    end

    def status
      @status ||= Status.new(Process.pid)
    end

    def test_redis_connection(redis_url)
      redis_test = Redis.new(url: redis_url)
      begin
        redis_test.ping
      rescue Redis::CannotConnectError => e
        puts "Cannot connect to Redis at '#{redis_url}'. Please check your Redis connection string. #{e.message}}"
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
  class MessageError < StandardError
    attr_reader :data

    def initialize(data = {})
      super
      @data = data
    end
  end

  # DeviceError is a custom error class that represents an error in the Chippy device,
  # with a specific error message indicating the type of error.
  class DeviceError < StandardError
    attr_reader :errors

    def initialize(errors, client_id)
      @errors = errors
      super("[client_id: #{client_id}] Device errors: #{errors.join(", ")}")
    end
  end

  # HandshakeError is a custom error class that represents a problem that occurs
  # during the handshake process with a Chippy device.
  class HandshakeError < StandardError; end

  class TimeoutError < StandardError; end
end
