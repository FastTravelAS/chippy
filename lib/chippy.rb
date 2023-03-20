require "logger"
require "active_support/tagged_logging"
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

module ChipReaders
  class << self
    def start
      port = ENV.fetch("CHIP_READER_PORT", 3004)
      ChipReaders::Server.new(port).run
    end

    attr_writer :logger

    def logger
      @logger ||= ActiveSupport::TaggedLogging.new(::Logger.new($stdout))
      @logger.tagged("Chippy")
    end
  end

  class MessageError < StandardError; end

  class DeviceError < StandardError; end

  class HandshakeError < StandardError; end
end
