module Chippy
  class Message
    # Message::Base is the base class for all message objects, providing common
    # functionality and attributes for working with messages.
    class Base
      include MessageHelper
      include MessageConstants

      def self.parse(data, options = {})
        data = normalize(data)

        new(data, **options).tap do |instance|
          instance.parse
        end
      end

      def initialize(data, type: :RESPONSE)
        @data = data
        @type = type
      end

      attr_reader :data, :type

      def to_a
        @data
      end

      def to_s
        bytes_to_hex_string(to_a)
      end

      def ==(other)
        data == other.data &&
          type == other.type
      end
    end
  end
end
