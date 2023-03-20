require "spec_helper"

RSpec.describe Chippy::Handshake do
  subject { described_class.new(connection, connections) }

  let(:connection) { instance_double(Chippy::Connection) }
  let(:connections) { {} }

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
      all_messages = Chippy::HandshakeMessages.initial +
        Chippy::HandshakeMessages.configure +
        Chippy::HandshakeMessages.enable

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

      # Subtract 3 because we skip the last read of each handshake category
      expect_any_instance_of(Chippy::MessageHandler).to receive(:handle).exactly(all_messages.count - 3).times

      subject.perform

      expect(request_counter).to eq(all_messages.count)
      expect(read_counter).to eq(all_messages.count - 3)
    end
  end

  context "when connections already holds a client_id" do
    let(:connections) { {"test_client_id" => connection_status} }

    context "and it's more than an hour old" do
      let(:connection_status) { instance_double(Chippy::ConnectionStatus, connected_at: 4.hours.ago, last_seen_at: 2.hours.ago ) }

      it "performs a full handshake" do
        allow(connection_status).to receive(:connect).with("test_client_id").once
        allow(connection_status).to receive(:touch).once
        allow(connection).to receive(:request)
        allow(connection).to receive(:read)
        allow(Chippy::HandshakeMessages).to receive(:configure).and_call_original

        subject.perform

        expect(Chippy::HandshakeMessages).to have_received(:configure).once
      end
    end

    context "and a client_id is not obtained" do
      let(:connection_status) { instance_double(Chippy::ConnectionStatus, connected_at: 30.minutes.ago) }
      before { allow(connection).to receive(:client_id).and_return(nil) }

      it "raises an exception" do
        allow(connection).to receive(:request)
        allow(connection).to receive(:read)

        expect {
          subject.perform
        }.to raise_error(Chippy::HandshakeError, "No beacon ID obtained")
      end
    end
  end
end
