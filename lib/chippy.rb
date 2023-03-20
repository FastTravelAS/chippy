require "logger"
require "active_support/tagged_logging"
require "active_support/isolated_execution_state"
require "active_support/core_ext/integer"

require_relative "chippy/logger_helper"
require_relative "chippy/connection"
require_relative "chippy/connection_status"
require_relative "chippy/handshake"
require_relative "chippy/handshake_messages"
require_relative "chippy/message"
require_relative "chippy/message/body"
require_relative "chippy/message/header"
require_relative "chippy/message_handler"
require_relative "chippy/server"
require_relative "chippy/version"

# TODO: Remove
require_relative "chippy/reading_job"

module Chippy
  DEFAULT_PORT = 44999
  DEFAULT_CONCURRENCY = 10
  DEFAULT_HOSTNAME = "0.0.0.0"

  class << self
    def start(options = {})
      port = options.fetch(:port, ENV.fetch("CHIPPY_PORT", DEFAULT_PORT)).to_i
      hostname = options.fetch(:hostname, ENV.fetch("CHIPPY_HOSTNAME", DEFAULT_HOSTNAME)).to_s
      concurrency = options.fetch(:concurrency, ENV.fetch("CHIPPY_CONCURRENCY", DEFAULT_CONCURRENCY)).to_i
      Chippy::Server.new(port: port, hostname: hostname, concurrency: concurrency).run
    end

    attr_accessor :logger

    def logger
      @logger ||= ActiveSupport::TaggedLogging.new(::Logger.new($stdout)).tap do |logger|
        logger.tagged("Chippy")
      end
    end
  end

  class MessageError < StandardError; end

  class DeviceError < StandardError; end

  class HandshakeError < StandardError; end
end
