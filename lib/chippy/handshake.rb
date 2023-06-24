module Chippy
  # Handshake performs the initial handshake process with a Chippy device,
  # establishing a connection and configuring the device as needed.
  class Handshake
    include ErrorHandler
    include LoggerHelper

    def initialize(connection, handler: MessageHandler.new(connection))
      @connection = connection
      @handler = handler
    end

    attr_reader :connection, :connections, :handler

    def perform
      log "Performing handshake", connection: connection
      client_id = process_messages(HandshakeMessages.initial, break_early: false)

      raise HandshakeError, "No beacon ID obtained" unless client_id

      process_messages(HandshakeMessages.on)
      log "Handshake complete for #{client_id}", connection: connection
    end

    private

    def process_messages(messages, break_early: true)
      client_id = nil
      messages.each_with_index do |message_data, index|
        message = Message.create(message_data, type: :REQUEST)
        log "Sending message #{message.name}"
        connection.request(message)

        # Break out of the loop if it's the last message in the array
        break if message_data == messages.last && break_early

        response = connection.read
        log "Response: #{response.inspect}" if response
        handler.handle(response) if response

        client_id ||= connection.client_id.presence
      rescue => error
        handle_error(error, connection)
        break
      end

      Thread.current[:handshake_complete] = true

      client_id
    end
  end
end
