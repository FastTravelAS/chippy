require_relative "message_helper"
require_relative "message_constants"

module Chippy
  # Message is the base class for creating and parsing messages sent between the
  # application and Chippy devices.
  class Message
    include MessageHelper
    include MessageConstants

    def self.create(data, options = {type: :RESPONSE})
      data = normalize(data)

      # Split the data into header and body parts
      header_data, body_data = split_data(data, options[:type])
      header = Header.parse(header_data, **options)
      body = Body.parse(body_data, **options)

      # Create and return a new Message instance
      new(header: header, body: body, **options)
    end

    def self.split_data(data, type)
      split_at = case type
      when :REQUEST
        1
      when :RESPONSE
        3
      end
      header = data.slice(0, split_at + 1)
      body = data.slice(split_at + 1, data.size)
      [header, body]
    end

    attr_reader :header, :body, :type, :created_at
    def initialize(header: nil, body: nil, type: :RESPONSE)
      @header = header
      @body = body
      @created_at = Time.now.utc
      @type = type
    end

    def valid?
      return false unless header.present? && body.present?

      body.data.length == message_length
    end

    def ok?
      return false unless valid?

      header.status == :OK
    end

    def to_a
      [header.to_a, body.to_a].flatten
    end

    def bytes
      bytes_to_hex_string(to_a)
    end

    def full_message
      to_a.pack("C*")
    end

    def name
      message_name
    end

    def header_attributes
      {
        name: header.message_name,
        klass: header.message_class,
        status: header.status,
        id: header.message_id,
        length: header.message_length
      }
    end

    def inspect
      data = header_attributes.merge(
        {
          content: bytes,
          created_at: @created_at.to_f
        }
      )

      "Message(%{name} - status: %{status} - length: %{length} - content: %{content})" % data
    end

    def ==(other)
      header_attributes == other.header_attributes &&
        full_message == other.full_message &&
        created_at == other.created_at
    end

    def eql?(other)
      self == other
    end

    def hash
      [header_attributes, full_message, created_at].hash
    end

    def message_class
      header&.message_class
    end

    def status
      header&.status
    end

    def message_id
      header&.message_id
    end

    def message_name
      header&.message_name
    end

    def message_length
      header&.message_length
    end
  end
end
