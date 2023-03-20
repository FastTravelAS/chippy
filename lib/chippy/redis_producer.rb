require "redis"

module Chippy
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
