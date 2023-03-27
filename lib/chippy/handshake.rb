module Chippy
  # Handshake performs the initial handshake process with a Chippy device,
  # establishing a connection and configuring the device as needed.
  class Handshake
    include LoggerHelper

    def initialize(connection, connections, handler: MessageHandler.new(connection))
      @connection = connection
      @connections = connections
      @handler = handler
    end

    attr_reader :connection, :connections, :handler

    def perform
      log "Performing handshake", connection: connection
      client_id = process_messages(HandshakeMessages.initial)

      if client_id
        connections[client_id] ||= ConnectionStatus.new
        connections[client_id].connect(client_id)
      else
        raise HandshakeError, "No beacon ID obtained"
      end

      if connections[client_id].last_seen_at.nil? || connections[client_id].last_seen_at < 1.hour.ago
        process_messages(HandshakeMessages.configure)
      end

      process_messages(HandshakeMessages.enable)

      connections[client_id].touch
      log "Finished handshake", connection: connection
    end

    private

    def process_messages(messages)
      client_id = nil
      messages.each_with_index do |message_data, index|
        message = Message.create(message_data, type: :REQUEST)
        connection.request(message)

        # Break out of the loop if it's the last message in the array
        break if message_data == messages.last

        response = connection.read
        handler.handle(response) if response

        client_id ||= connection.client_id.presence
      end
      client_id
    end
  end
end
