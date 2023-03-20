module Chippy
  module MessageHelper
    def self.included(klass)
      klass.extend(ClassMethods)
      klass.include(InstanceMethods)
    end

    module ClassMethods
      def normalize(data)
        case data
        when String
          parse_byte_string(data)
        when Array
          if data.all?(String)
            hex_string_to_bytes(data.join)
          elsif data.all?(Integer)
            data
          else
            raise ArgumentError, "Array must contain integers or hex-encoded strings"
          end
        else
          raise ArgumentError, "Invalid data type: #{data.class}"
        end
      end

      def parse_byte_string(str)
        if /\A[\da-fA-F]+\z/.match?(str)
          # input string contains only hexadecimal digits
          str.scan(/../).map(&:hex)
        else
          # input string contains escape sequences
          str.unpack("C*")
        end
      end

      def binary_string?(str)
        # Check whether the string includes any non-printable ASCII characters
        str.each_byte do |b|
          return true if b < 32 || b > 126
        end
        false
      end

      def binary_string_to_bytes(str)
        str.bytes
      end

      def hex_string_to_bytes(str)
        # Convert the hex-encoded string to a binary string, and then to an array of integers
        [str].pack("H*").bytes
      end
    end

    module InstanceMethods
      def bytes_to_hex_string(bytes)
        bytes.map { |i| i.to_s(16).rjust(2, "0") }.join("")
      end
    end
  end
end
