module Chippy
  # Connection represents a connection to a Chippy device, handling the
  # sending and receiving of messages over the underlying socket.
  class Connection
    include LoggerHelper

    OPERATIONAL_MODES = {
      0 => :NON_TRANSACTION_MODE,
      1 => :TRANSACTION_MODE
    }

    attr_reader :client
    attr_accessor :client_id
    attr_reader :operational_mode

    def initialize(client, client_id = 0)
      @client = client
      @client_id = client_id
    end

    def read
      data = client.read(Message::HEADER_SIZE)

      return if data.nil? || data.empty?

      Sentry.configure_scope do |scope|
        scope.set_context("incoming raw header", data: data)
      end

      header = Message::Header.parse(data)

      length_of_data = header.message_length
      data = client.read(length_of_data)

      Sentry.configure_scope do |scope|
        scope.set_context("incoming raw body", data: data)
      end

      # Calculate the remaining data length
      remaining_data_length = length_of_data - data.bytesize

      body = Message::Body.parse(data)
      message = Message.new(header: header, body: body)

      Sentry.configure_scope do |scope|
        scope.set_context("full message", data: data)
      end

      raise Chippy::MalformedMessageError.new(message, remaining_data_length: remaining_data_length) unless message.ok?

      message
    end

    def request(message)
      Sentry.configure_scope do |scope|
        scope.set_context("request", data: message.full_message.to_s)
      end

      log message, connection: self, direction: :out if client.send(message.full_message, 0)
    end

    delegate :close, to: :client

    def discard_remaining_data(remaining_data_length)
      return unless remaining_data_length

      # Read and discard the remaining data
      client.read(remaining_data_length)
    end

    def operational_mode=(mode)
      log "Setting operational mode to #{mode}"
      @operational_mode = OPERATIONAL_MODES[mode]
    end

    def in_transaction_mode?
      operational_mode == :TRANSACTION_MODE
    end
  end
end
