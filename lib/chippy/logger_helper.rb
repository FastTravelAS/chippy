module Chippy
  # LogWriter is a utility class for writing logs, providing a simple interface
  # for outputting log messages with tags.
  class LogWriter
    attr_reader :logger

    def initialize(logger)
      @logger = logger
    end

    def log(message, tags)
      formatted_message = Chippy.log_formatter.call("info", Time.now.utc, "Chippy", message)

      write_to_log(formatted_message, :info, tags)
    end

    def log_error(e, tags)
      formatted_message = Chippy.log_formatter.call("error", Time.now.utc, "Chippy", e.inspect)

      write_to_log(formatted_message, :error, tags)
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
      tags = [beacon_string(connection&.client_id), direction_string].compact
      LogWriter.new(Chippy.logger).log(message, tags)
    end

    def log_error(e, connection: nil, notify: false)
      Sentry.capture_exception(e) if notify
      tags = [beacon_string(connection&.client_id)].compact
      LogWriter.new(Chippy.logger).log_error(e, tags)
    end

    private

    def beacon_string(beacon)
      return nil unless beacon

      "Beacon: #{beacon}"
    end
  end
end
