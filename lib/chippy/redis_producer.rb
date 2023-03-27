require "redis"

module Chippy
  # RedisProducer is responsible for publishing messages to a Redis message queue,
  # allowing other components of the application to process them asynchronously.
  class RedisProducer
    def initialize(list_name, redis_options = {})
      @list_name = list_name
      @redis = Redis.new(redis_options)
    end

    def push(message)
      message = message.to_json if message.is_a?(Hash)
      @redis.rpush(@list_name, message)
    end
  end
end
