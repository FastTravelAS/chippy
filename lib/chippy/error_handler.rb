module Chippy
  module ErrorHandler
    def handle_error(error, connection)
      should_close_connection = false

      case error
      when Chippy::DeviceError
        #   log_error(error, connection: connection, notify: true)
        should_close_connection = false
      when Chippy::MalformedMessageError
        remaining_data = connection.discard_remaining_data(error.remaining_data_length) if error.remaining_data_length&.positive?
        Sentry.capture_exception(error, extra: {remaining_data: remaining_data, length: error.remaining_data_length})
      when EOFError, Errno::EPIPE, Errno::ECONNRESET, IOError, Chippy::HandshakeError
        should_close_connection = true
      when Chippy::MessageError
        Sentry.configure_scope do |scope|
          scope.set_context("raw message", **error.data)
        end
        should_close_connection = false
      else
        should_close_connection = true
        # log_error(error, connection: connection, notify: true)
      end

      # TODO: Remove this when we're ready to go live. Keeping this for now to help with debugging.
      log_error(error, connection: connection, notify: true)

      connection.close if should_close_connection
    end
  end
end
