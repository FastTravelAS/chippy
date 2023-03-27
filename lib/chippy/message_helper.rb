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
          parse_string(data)
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

      def parse_string(str)
        if /\A[\da-fA-F]+\z/.match?(str)
          # input string contains only hexadecimal digits
          str.scan(/../).map(&:hex)
        else
          # input string contains escape sequences
          str.unpack("C*")
        end
      end

      def hex_string_to_bytes(str)
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
