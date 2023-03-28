require "spec_helper"

RSpec.describe Chippy::Client::RedisConsumer do
  let(:queue_name) { "test_queue" }
  let(:redis) { Redis.new }
  let(:consumer) { described_class.new(queue_name) }

  before do
    redis.flushdb # Clear the Redis database before each test
  end

  describe "#initialize" do
    it "sets the queue name" do
      expect(consumer.instance_variable_get(:@queue_name)).to eq(queue_name)
    end

    it "initializes a Redis instance" do
      expect(consumer.instance_variable_get(:@redis)).to be_a(Redis)
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
