require "spec_helper"

RSpec.describe Chippy::Handshake do
  subject(:handshake) { described_class.new(connection, handler: message_handler) }

  let(:socket) { instance_double(UNIXSocket, close: true) }
  let(:connection) { Chippy::Connection.new(socket, "test_client_id") }
  let(:message_handler) { Chippy::MessageHandler.new(connection) }

  let(:request_messages) {
    [
      Chippy::Message.create(Chippy::Messages.operational_mode_non_transaction, type: :REQUEST),
      Chippy::Message.create(Chippy::Messages.get_operational_mode, type: :REQUEST),
      Chippy::Message.create(Chippy::Messages.get_dsrc_configuration, type: :REQUEST),
      Chippy::Message.create(Chippy::Messages.get_status, type: :REQUEST),
      Chippy::Message.create(Chippy::Messages.set_beacon_time.call, type: :REQUEST),
      Chippy::Message.create(Chippy::Messages.define_applications[0], type: :REQUEST),
      Chippy::Message.create(Chippy::Messages.define_applications[1], type: :REQUEST),
      Chippy::Message.create(Chippy::Messages.set_extended, type: :REQUEST),
      Chippy::Message.create(Chippy::Messages.operational_mode_transaction, type: :REQUEST),
      Chippy::Message.create(Chippy::Messages.get_operational_mode, type: :REQUEST)
    ]
  }

  let(:expected_responses) {
    [
      Chippy::Message.create([0x01, 0x00, 0x01, 0x00], type: :RESPONSE), # operational_mode_non_transaction
      Chippy::Message.create([0x01, 0x00, 0x02, 0x01, 0x00], type: :RESPONSE), # get_operational_mode
      Chippy::Message.create([0x01, 0x00, 0x0e, 0x0b, 0x00, 0x13, 0x81, 0x0a, 0x00, 0x09, 0x00, 0x00, 0x00, 0x00, 0x00], type: :RESPONSE), # get_dsrc_configuration
      Chippy::Message.create([0x01, 0x00, 0x03, 0x04, 0x00, 0x00, 0x00, 0x04], type: :RESPONSE), # get_status
      Chippy::Message.create([0x01, 0x00, 0x0a, 0x00], type: :RESPONSE), # set_beacon_time
      Chippy::Message.create([0x01, 0x00, 0x2c, 0x02, 0x00, 0x06], type: :RESPONSE), # define_applications[0]
      Chippy::Message.create([0x01, 0x00, 0x2c, 0x02, 0x00, 0x06], type: :RESPONSE), # define_applications[1]
      Chippy::Message.create([0x01, 0x00, 0x3c, 0x00], type: :RESPONSE), # set_extended
      Chippy::Message.create([0x01, 0x00, 0x01, 0x01], type: :RESPONSE), # operational_mode_transaction
      Chippy::Message.create([0x01, 0x00, 0x02, 0x01, 0x01], type: :RESPONSE) # get_operational_mode
    ]
  }

  before do
    Chippy.setup_redis
    allow(connection).to receive(:client_id).and_return("test_client_id")
  end

  around do |example|
    Timecop.freeze do
      example.run
    end
  end

  describe "#perform" do
    before do
      allow(Chippy.status).to receive(:pid).and_return(12345)
      allow(Chippy.redis).to receive(:set).with(any_args)
      allow(Chippy.redis).to receive(:hset).with(any_args)
      allow(Chippy.redis).to receive(:hexists).with(any_args).and_return(false)
      allow(connection).to receive(:request).and_return(*request_messages)
      allow(connection).to receive(:read).and_return(*expected_responses)
      allow(message_handler).to receive(:handle).and_call_original
    end

    context "when there are no errors" do
      it "processes messages correctly" do
        handshake.perform

        expect(message_handler).to have_received(:handle).exactly(request_messages.count).times
        expect(connection).to have_received(:request).exactly(request_messages.count).times
        expect(connection).to have_received(:read).exactly(expected_responses.count).times
      end

      it "sets the status of the operational mode" do
        handshake.perform

        expect(Chippy.status.client_status("test_client_id")).to eq(:TRANSACTION_MODE)
      end

      it "keeps track on the client being initialized" do
        expect(Chippy.status).not_to be_client_initialized("test_client_id")

        handshake.perform
        allow(Chippy.redis).to receive(:hexists).with(any_args).and_return(true) # Mocking the key being set

        expect(Chippy.status).to be_client_initialized("test_client_id")
      end
    end

    context "when there is an error" do
      it "retries the message until it succeeds" do
        expected_responses.unshift(Chippy::Message.create([0x01, 0x13, 0x01, 0x00], type: :RESPONSE)) # Unhealthy
        allow(connection).to receive(:read).and_return(*expected_responses)

        handshake.perform

        expect(message_handler).to have_received(:handle).exactly(request_messages.count + 1).times
        expect(connection).to have_received(:request).exactly(request_messages.count + 1).times
        expect(connection).to have_received(:read).exactly(expected_responses.count).times
      end

      it "attempts to reset beacon" do
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with("CHIPPY_TRX_USER").and_return("hello")
        allow(ENV).to receive(:fetch).with("CHIPPY_TRX_PASSWORD").and_return("world")

        expected_responses[0] = Chippy::Message.create([0x01, 0x13, 0x01, 0x00], type: :RESPONSE) # TIMEOUT_ERROR
        allow(connection).to receive(:read).and_return(*expected_responses)
        allow(connection).to receive(:close)

        expect { handshake.perform }.to raise_error(Chippy::TimeoutError, "Device unresponsive, attempting reset")
      end

      it "saves any messages not expected and process them later" do
        expected_responses.insert(1, Chippy::Message.create([0x00, 0x00, 0x00, 0x00], type: :RESPONSE)) # KEEP_ALIVE
        expected_responses.insert(1, Chippy::Message.create([0x00, 0x00, 0x00, 0x00], type: :RESPONSE)) # KEEP_ALIVE
        allow(connection).to receive(:read).and_return(*expected_responses)
        allow(message_handler).to receive(:handle_keep_alive)

        handshake.perform

        expect(message_handler).to have_received(:handle).exactly(request_messages.count + 2).times
        expect(connection).to have_received(:request).exactly(request_messages.count).times
        expect(connection).to have_received(:read).exactly(expected_responses.count).times
        expect(message_handler).to have_received(:handle_keep_alive).exactly(2).times
      end
    end

    describe "and a client_id is not obtained" do
      before { allow(connection).to receive(:client_id).and_return(nil) }

      it "raises an exception" do
        expect {
          handshake.perform
        }.to raise_error(Chippy::HandshakeError, "No beacon ID obtained")
      end
    end
  end
end
