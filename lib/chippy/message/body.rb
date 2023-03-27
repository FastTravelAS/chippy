require_relative "base"

module Chippy
  class Message
    # Message::Body is a utility class for handling the body content of messages,
    # providing methods for parsing and manipulating message data.
    class Body < Base
      def parse
        @data # TODO: Do more here.
      end
    end
  end
end
