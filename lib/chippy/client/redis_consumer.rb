module Chippy
  module Client
    class RedisConsumer
      class << self
        attr_accessor :queue_name, :enabled
      end

      def self.configure
        yield self
      end

      def initialize(queue_name = nil)
        @queue_name = queue_name || self.class.queue_name
        @redis = Redis.new
      end

      def listen
        Thread.new do
          loop do
            # Block and wait for a message to be available in the list
            _, message = @redis.blpop(@queue_name, timeout: 0)

            handle_message(message)
          end
        end
      end

      def handle_message(message)
        # Do something with the message
        puts "Received message #{message} on queue #{@queue_name}"
      end
    end
  end
end
