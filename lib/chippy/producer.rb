module Chippy
  # Producer is responsible for publishing messages to a Redis message queue,
  # allowing other components of the application to process them asynchronously.
  class Producer
    def initialize(list_name, redis_client)
      @list_name = list_name
      @redis_client = redis_client
    end

    def push(message)
      message = message.to_json if message.is_a?(Hash)
      @redis_client.rpush(@list_name, message)
    end
  end
end
