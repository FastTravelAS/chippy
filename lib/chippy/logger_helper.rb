module Chippy
  # LogWriter is a utility class for writing logs, providing a simple interface
  # for outputting log messages with tags.
  class LogWriter
    attr_reader :logger

    def initialize(logger)
      @logger = logger
    end

    def log(message, tags)
      if message.is_a? Message
        message = message.inspect
      end
      write_to_log(message, :info, tags)
    end

    def log_error(e, tags)
      write_to_log(e, :error, tags)
    end

    private

    def write_to_log(message, log_level, tags)
      if logger.respond_to?(:tagged)
        logger.tagged(tags).send(log_level, message)
      else
        logger.send(log_level, message)
      end
    end
  end

  # LoggerHelper is a utility module that provides helper methods for logging,
  # simplifying the process of logging messages in other classes.
  module LoggerHelper
    LOG_DIRECTIONS = {
      in: :IN,
      out: :OUT
    }

    def log(message, connection: nil, direction: nil)
      direction_string = LOG_DIRECTIONS.fetch(direction, nil)
      tags = [pid_string, beacon_string(connection&.client_id), direction_string].compact
      LogWriter.new(Chippy.logger).log(message, tags)
    end

    def log_error(e, connection: nil, notify: false)
      Sentry.capture_exception(e) if notify
      tags = [pid_string, beacon_string(connection&.client_id)].compact
      LogWriter.new(Chippy.logger).log_error(e, tags)
    end

    private

    def beacon_string(beacon)
      return nil unless beacon

      "Beacon: #{beacon}"
    end

    def pid
      Process.pid
    end

    def pid_string
      "PID: #{pid}"
    end
  end
end
