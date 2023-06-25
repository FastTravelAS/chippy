module Chippy
  # Handshake performs the initial handshake process with a Chippy device,
  # establishing a connection and configuring the device as needed.
  class Handshake
    include ErrorHandler
    include LoggerHelper

    def initialize(connection, handler: MessageHandler.new(connection))
      @connection = connection
      @handler = handler
      @message_queue = []
    end

    attr_reader :connection, :connections, :handler

    def perform
      log "Performing handshake", connection: connection

      process_message(
        message: Message.create(Messages.operational_mode_non_transaction, type: :REQUEST),
        retry_on: :TIMEOUT_ERROR,
        retry_interval: 5,
        max_attempts: 3,
        on_max_attempts: -> { reset_beacon }
      )

      process_message(
        message: Message.create(Messages.get_operational_mode, type: :REQUEST),
        on_max_attempts: -> { raise HandshakeError, "Failed query for operational mode" }
      )

      process_message(
        message: Message.create(Messages.get_dsrc_configuration, type: :REQUEST),
        on_max_attempts: -> { raise HandshakeError, "Failed to receive DSRC configuration" }
      )

      client_id = connection.client_id
      raise HandshakeError, "No beacon ID obtained" unless client_id
      skip_config = Chippy.status.client_initialized?(client_id)

      unless skip_config
        process_message(
          message: Message.create(Messages.get_status, type: :REQUEST),
          on_max_attempts: -> { raise HandshakeError, "Failed query for status" }
        )

        process_message(
          message: Message.create(Messages.set_beacon_time.call, type: :REQUEST),
          on_max_attempts: -> { raise HandshakeError, "Failed to set beacon time" }
        )

        Messages.define_applications.each do |application|
          process_message(
            message: Message.create(application, type: :REQUEST),
            on_max_attempts: -> { raise HandshakeError, "Failed to define application" }
          )
        end

        process_message(
          message: Message.create(Messages.set_extended, type: :REQUEST),
          on_max_attempts: -> { raise HandshakeError, "Failed to set extended" }
        )
      end

      process_message(
        message: Message.create(Messages.operational_mode_transaction, type: :REQUEST),
        retry_on: :TIMEOUT_ERROR,
        retry_interval: 5,
        max_attempts: 3,
        on_max_attempts: -> { reset_beacon }
      )

      process_message(
        message: Message.create(Messages.get_operational_mode, type: :REQUEST),
        on_max_attempts: -> { raise HandshakeError, "Failed query for operational mode" }
      )

      Thread.current[:handshake_complete] = true
      Chippy.status.set_status_online

      log "Handshake complete for #{client_id}", connection: connection

      if @message_queue.present?
        log "Processing leftover message queue", connection: connection
        @message_queue.each do |message|
          handler.handle(message)
        end
      end
    end

    private

    def process_message(message:, retry_on: nil, retry_interval: 0, max_attempts: 1, on_max_attempts: nil)
      log "Sending message: #{message.name}", connection: connection

      attempts = 0
      message_sent = false
      result = nil
      original_response = nil

      loop do
        if attempts >= max_attempts
          log "Max attempts reached, #{message.name}"
          on_max_attempts.call if on_max_attempts.present? && on_max_attempts.respond_to?(:call)
          break
        end

        attempts += 1

        unless message_sent
          connection.request(message)
          message_sent = true
        end

        response = connection.read

        next if response.nil?

        # If we get an unexpected message, like a keep alive, we need to keep reading until we get the original response.
        # So we'll keep it in the queue and process it later.
        [:KEEP_ALIVE, :CONNECT_TRANSPONDER_REPORT].include?(response.name)
        if response.name == :KEEP_ALIVE
          @message_queue << response
          attempts -= 1
          next
        end

        if original_response.nil? || response.name === message.name
          original_response = response
        end

        result = handler.handle(response)

        if original_response.name == message.name && original_response.status == :OK
          # We can break out of the loop
          break
        elsif retry_on.present? && original_response.name == message.name && original_response.status == retry_on
          log "Retrying on #{retry_on}"
          # We need to go back and send the message again, and count the number of times we've done this
          message_sent = false

          if ENV["CHIPPY_ENV"] == "test"
            sleep 0.1
          elsif retry_interval > 0
            sleep retry_interval
          end
        end
      end

      result
    end

    def reset_beacon
      process_message(message: Chippy::Message.create(Chippy::Messages.reset_beacon, type: :REQUEST))
      raise TimeoutError, "Device unresponsive, attempting reset"
    end
  end
end
