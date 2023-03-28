require "spec_helper"
require "securerandom"

RSpec.describe Chippy::RedisProducer do
  let(:queue_name) { "chippy:readings:test" }
  let(:producer) { described_class.new(queue_name) }
  let(:redis) { Redis.new }

  before do
    redis.del(queue_name) # Clear the test queue before each test
  end

  describe "#push" do
    it "pushes a message to the queue" do
      message = SecureRandom.hex(10)
      producer.push(message)

      expect(redis.lrange(queue_name, 0, -1)).to eq([message])
    end
  end
end
