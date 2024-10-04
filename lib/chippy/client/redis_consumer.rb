module Chippy
  module Client
    class RedisConsumer
      class << self
        attr_accessor :queue_name, :enabled, :message_handler
      end

      def self.configure
        yield self
      end

      def initialize(queue_name = nil, redis = nil, &block)
        @queue_name = queue_name || self.class.queue_name
        @redis = redis || Redis.new
        @message_handler = block || self.class.message_handler
      end

      def listen
        Thread.new do
          loop do
            # Block and wait for a message to be available in the list
            _, message = @redis.blpop(@queue_name, timeout: 0)

            handle_message(message)
          rescue => error
            Sentry.capture_exception(error)
          end
        end
      end

      def handle_message(message)
        if @message_handler
          @message_handler.call(message)
        else
          # Do something with the message (default behavior)
          puts "Received message #{message} on queue #{@queue_name}"
        end
      end
    end
  end
end
