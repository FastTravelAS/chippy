require_relative "base"

module Chippy
  class Message
    # Message::Header is a utility class for handling the header section of messages,
    # providing methods for parsing and constructing header data for communication
    # between the application and Chippy devices.
    class Header < Base
      attr_reader :message_class, :status, :response_status, :message_id, :message_length, :message_name

      def self.parse(data, options = {})
        raise ArgumentError if data.empty?

        super(data, options)
      end

      def parse
        if type == :RESPONSE
          @message_class = MESSAGE_CLASSES.fetch(data[0])
          @status = MESSAGE_RESPONSE_STATUS.fetch(data[1])
          @message_name = MESSAGE_IDS.fetch(data[2])
          @message_id = data[2]
          @message_length = data[3]
        elsif type == :REQUEST
          @message_class = :REQUEST
          @status = :OK
          @message_name = MESSAGE_IDS.fetch(data[0])
          @message_id = data[0]
          @message_length = data[1]
        end
      rescue KeyError
        Sentry.configure_scope do |scope|
          scope.set_context(
            "message", **data
          )
        end
        raise MessageError
      end
    end
  end
end
