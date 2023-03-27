require "logger"
require "active_support/tagged_logging"
require "active_support/isolated_execution_state"
require "active_support/core_ext/integer"

require_relative "chippy/logger_helper"
require_relative "chippy/cli"
require_relative "chippy/connection"
require_relative "chippy/connection_status"
require_relative "chippy/handshake"
require_relative "chippy/handshake_messages"
require_relative "chippy/message"
require_relative "chippy/message/body"
require_relative "chippy/message/header"
require_relative "chippy/message_handler"
require_relative "chippy/redis_producer"
require_relative "chippy/server"
require_relative "chippy/version"

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

  class MalformedMessageError < StandardError
    attr_reader :remaining_data_length

    def initialize(message = nil, remaining_data_length: nil)
      super(message)
      @remaining_data_length = remaining_data_length
    end
  end

  class MessageError < StandardError; end

  class DeviceError < StandardError
    attr_reader :errors

    def initialize(errors)
      @errors = errors
      super("Device errors: #{errors.join(", ")}")
    end
  end

  class HandshakeError < StandardError; end
end
