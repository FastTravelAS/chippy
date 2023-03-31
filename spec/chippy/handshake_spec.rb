require "spec_helper"

RSpec.describe Chippy::Handshake do
  subject(:handshake) { described_class.new(connection, handler: message_handler) }

  let(:connection) { instance_double(Chippy::Connection) }
  let(:message_handler) { instance_double(Chippy::MessageHandler) }

  before do
    allow(connection).to receive(:client_id).and_return("test_client_id")
  end

  around do |example|
    Timecop.freeze do
      example.run
    end
  end

  describe "#perform" do
    it "processes messages correctly" do
      all_messages = Chippy::HandshakeMessages.all

      request_counter = 0
      read_counter = 0

      allow(connection).to receive(:request) do |message|
        expect(message).to be_a(Chippy::Message)
        expect(message.to_a.flatten).to eq(all_messages[request_counter])
        request_counter += 1
      end

      allow(connection).to receive(:read) do
        read_counter += 1
      end

      allow(message_handler).to receive(:handle)

      handshake.perform

      # Subtract 3 because we skip the last read of each handshake category
      expect(message_handler).to have_received(:handle).exactly(all_messages.count - 1).times
      expect(request_counter).to eq(all_messages.count)
      expect(read_counter).to eq(all_messages.count - 1)
    end

    describe "and a client_id is not obtained" do

      before { allow(connection).to receive(:client_id).and_return(nil) }

      it "raises an exception" do
        allow(connection).to receive(:request)
        allow(connection).to receive(:read)

        expect {
          handshake.perform
        }.to raise_error(Chippy::HandshakeError, "No beacon ID obtained")
      end
    end
  end
end
