require "spec_helper"

class FakeTCPClient
  def initialize(message)
    @canned_message = message
  end

  def read(split_at)
    if @canned_message.empty?
      return ""
    end

    response = @canned_message.slice(0, split_at)
    @canned_message = if @canned_message.size == response.size
      []
    else
      @canned_message.slice(split_at..)
    end

    response
  end
end

RSpec.describe Chippy::Connection do
  def enc(message)
    [message].pack("H*")
  end

  describe "#read" do
    let!(:long_message) { enc("0200172c01d60003731a02000106a40002000501020201200e3086060000668611ffff0000000000992a16ec00000000" * 3) }
    let!(:wrong_message) { enc("00200172c01d60003731a02000106a40002000501020201200e3086060000668611ffff0000000000992a16ec0000000" * 3) }
    let!(:simple_malformed_message) { enc("0000000400") }
    let!(:connection) { described_class.new(FakeTCPClient.new(long_message)) }
    let!(:out_of_frame_connection) { described_class.new(FakeTCPClient.new(wrong_message)) }
    let!(:malformed_message) { described_class.new(FakeTCPClient.new(simple_malformed_message)) }

    it "reads from buffer and returns a message" do
      message = connection.read
      expect(message).to be_instance_of Chippy::Message
    end

    it "uses message attributes to define message frame" do
      messages = []
      3.times do
        messages << connection.read
      end

      expect(messages.size).to eq 3

      connection.read
    end

    it "raises Chippy::MessageError if message is invalid" do
      expect {
        out_of_frame_connection.read
      }.to raise_error Chippy::MessageError
    end

    it "raises Chippy::MalformedMessageError with the correct remaining data length" do
      expect {
        malformed_message.read
      }.to raise_error(Chippy::MalformedMessageError) { |error|
             expect(error.remaining_data_length).to eq(3) # 3 bytes missing
           }
    end
  end
end
