require "socket"

module Chippy
  # Server is the main entry point for the application, handling incoming connections
  # and managing the overall communication with Chippy devices.
  class Server
    include ErrorHandler
    include LoggerHelper

    def initialize(options = {})
      @port, @hostname, @concurrency = options.values_at(:port, :hostname, :concurrency)
      @threads = ThreadGroup.new

      begin
        @socket = TCPServer.new(hostname, port)
        @socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR, true)
      rescue Errno::EADDRINUSE
        puts "Port #{port} is already in use. Please choose another port."
        exit 1
      end
    end

    attr_reader :threads, :socket, :concurrency, :port, :hostname

    def trap_signals
      trap("INT") { raise Interrupt }
      trap("TERM") { raise Interrupt }
    end

    def handle_exit
      at_exit do
        log "Shutting down server"
        Chippy.status.set_status_offline
        threads.list.each do |t|
          log "Closing connection with #{t[:connection].client_id}" if t[:connection]&.client_id
          t[:connection]&.close
          t.kill
        end
        close
      end
    end

    def run
      trap_signals
      handle_exit

      log "Started chip reader server on #{hostname}:#{port}"

      Chippy.status.set_status_online

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
          Thread.current[:handshake_complete] = false
          connection = Connection.new(socket.accept)
          Thread.current[:connection] = connection
          handle_connection(connection)
        end
      end
    end

    def handle_connection(connection)
      handler = MessageHandler.new(connection)

      # Normal loop
      loop do
        unless Thread.current[:handshake_complete]
          log "Will handshake"
          Handshake.new(connection).perform
        end

        message = connection.read
        if message
          handler.handle(message)
        else
          break
        end
        yield if block_given?
      rescue => error
        handle_error(error, connection)
        break
      end
    end
  end
end
