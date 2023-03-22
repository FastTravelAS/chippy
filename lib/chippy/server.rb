require "socket"

module Chippy
  class Server
    include LoggerHelper

    def initialize(options = {})
      @port, @hostname, @concurrency = options.values_at(:port, :hostname, :concurrency)
      @threads = ThreadGroup.new
      @connections = {}

      begin
        @socket = TCPServer.new(hostname, port)
      rescue Errno::EADDRINUSE
        puts "Port #{port} is already in use. Please choose another port."
        exit 1
      end
    end

    attr_reader :threads, :connections, :socket, :concurrency, :port, :hostname

    def trap_signals
      trap("INT") { raise Interrupt }
      trap("TERM") { raise Interrupt }
    end

    def handle_exit
      at_exit do
        log "Shutting down server"
        threads.list.each(&:kill)
        close
      end
    end

    def run
      trap_signals
      handle_exit

      log "Started chip reader server on #{hostname}:#{port}"

      Thread.abort_on_exception = true

      concurrency.times do
        threads.add spawn_thread
      end

      sleep
    rescue Interrupt
      exit(0)
    end

    def close
      socket.close
    end

    def spawn_thread
      Thread.new do
        loop do
          connection = Connection.new(socket.accept)

          begin
            handshake = Handshake.new(connection, connections)
            handshake.perform
            handle_connection(connection)
          rescue => e
            handle_error(e, connection)
          end
        end
      end
    end

    def handle_connection(connection)
      handler = MessageHandler.new(connection)

      # Normal loop
      loop do
        message = connection.read
        if message
          handler.handle(message)
          connections[connection.client_id].touch
        else
          break
        end
        yield if block_given?
      end
    rescue => e
      handle_error(e, connection)
    end

    private

    def handle_error(error, connection)
      should_close_connection = false

      case error
      when Chippy::MalformedMessageError
        connection.discard_remaining_data(error.remaining_data_length) if error.remaining_data_length&.positive?
      when EOFError, Errno::EPIPE, Errno::ECONNRESET
        should_close_connection = true
      else
        # log_error(error, connection: connection, notify: true)
      end

      # TODO: Remove this when we're ready to go live. Keeping this for now to help with debugging.
      log_error(error, connection: connection, notify: true)

      connection.close if should_close_connection
    end
  end
end
