require "spec_helper"
require "mock_redis"

RSpec.describe Chippy::Client::RedisConsumer do
  let(:queue_name) { "test_queue" }
  let(:redis) { MockRedis.new }
  let(:consumer) { described_class.new(queue_name, redis) }

  describe "#initialize" do
    it "sets the queue name" do
      expect(consumer.instance_variable_get(:@queue_name)).to eq(queue_name)
    end

    it "initializes a Redis instance" do
      expect(consumer.instance_variable_get(:@redis)).to be_a(MockRedis)
    end
  end

  describe "#listen" do
    it "listens for messages and calls the handle_message method" do
      message = "test_message"
      redis.rpush(queue_name, message)

      allow(consumer).to receive(:handle_message).with(message)

      listener = consumer.listen
      sleep 0.5 # Give the listener some time to process the message
      listener.kill # Kill the listener thread after processing the message

      expect(consumer).to have_received(:handle_message).with(message)
    end

    it "will not crash the thread if an exception is thrown" do
      message = "test_message"
      redis.rpush(queue_name, message)

      allow(consumer).to receive(:handle_message).with(message)
      allow(redis).to receive(:blpop).and_raise(StandardError)

      listener = consumer.listen
      sleep 0.2

      expect(consumer).not_to have_received(:handle_message).with(message)

      # Restore the original method
      allow(redis).to receive(:blpop).and_call_original

      sleep 0.2

      expect(consumer).to have_received(:handle_message).with(message)

      listener.kill
    end
  end

  describe "#handle_message" do
    it "outputs a message" do
      message = "test_message"
      expect do
        consumer.handle_message(message)
      end.to output("Received message #{message} on queue #{queue_name}\n").to_stdout
    end
  end

  describe "custom message handler" do
    it "calls the custom message handler when provided" do
      custom_handler = lambda do |message|
        puts "Custom handler: Received message #{message} on queue #{queue_name}\n"
      end

      consumer = described_class.new(queue_name, &custom_handler)

      message = "test_message"
      expect do
        consumer.handle_message(message)
      end.to output("Custom handler: Received message #{message} on queue #{queue_name}\n").to_stdout
    end
  end
end
