module Chippy
  class Connection
    include LoggerHelper
    attr_reader :client
    attr_accessor :client_id
    def initialize(client, client_id = 0)
      @client = client
      @client_id = client_id
    end

    def read
      data = client.read(Message::HEADER_SIZE)

      return if data.nil? || data.empty?

      header = Message::Header.parse(data)

      length_of_data = header.message_length
      data = client.read(length_of_data)

      # Calculate the remaining data length
      remaining_data_length = length_of_data - data.bytesize

      body = Message::Body.parse(data)
      message = Message.new(header: header, body: body)

      raise Chippy::MalformedMessageError.new(remaining_data_length: remaining_data_length) unless message.ok?

      message
    end

    def request(message)
      log message, connection: self, direction: :out if client.send(message.full_message, 0)
    end

    delegate :close, to: :client

    def discard_remaining_data(remaining_data_length)
      return unless remaining_data_length

      # Read and discard the remaining data
      client.read(remaining_data_length)
    end
  end
end
