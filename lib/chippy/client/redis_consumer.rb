module Chippy
  module Client
    class RedisConsumer
      def initialize(queue_name)
        @queue_name = queue_name
        @redis = Redis.new
      end

      def listen
        Thread.new do
          loop do
            # Block and wait for a message to be available in the "chippy:readings" list
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
