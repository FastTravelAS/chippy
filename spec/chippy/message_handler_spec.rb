require "spec_helper"

RSpec.describe Chippy::MessageHandler do
  subject(:message_handler) { described_class.new(connection) }

  let(:connection) { instance_double(Chippy::Connection) }
  let(:redis) { instance_double(Redis) }

  describe "#handle" do
    let(:message) { instance_double(Chippy::Message, name: name, body: body, created_at: Time.now) }
    let(:name) { :CONNECT_TRANSPONDER_REPORT }
    let(:body) { "020201200e12345678ffff00000000" }

    before do
      Chippy.setup_producer("test", url: "redis://localhost:6379/0")
      allow(connection).to receive(:client_id).and_return(1)
      allow(connection).to receive(:client_id=)
      allow(connection).to receive(:request)
      allow(Chippy.producer).to receive(:push)
    end

    context "when the message name is :CONNECT_TRANSPONDER_REPORT" do
      it "queues a ReadingJob with the chip, client_id, and created_at" do
        message_handler.handle(message)
        expect(Chippy.producer).to have_received(:push).with(hash_including(data: a_kind_of(String), client_id: a_kind_of(Integer), timestamp: a_kind_of(Float)))
      end
    end

    context "when the message name is :KEEP_ALIVE" do
      let(:name) { :KEEP_ALIVE }

      before do
        allow(Chippy).to receive(:redis).and_return(redis)
        allow(Chippy.redis).to receive(:hset)
      end

      it "sends a keepalive request" do
        message_handler.handle(message)
        expect(connection).to have_received(:request).with(an_instance_of(Chippy::Message))
        expect(Chippy.redis).to have_received(:hset).with("chippy:last_keep_alive", 1, a_kind_of(Integer))
      end
    end

    context "when the message name is :GET_STATUS" do
      let(:name) { :GET_STATUS }
      let(:body) { [0, 0, 0, 32] }

      it "raises a DeviceError with the error message" do
        expect { message_handler.handle(message) }.to raise_error(Chippy::DeviceError, "[client_id: 1] Device errors: ERROR_INTERNAL_VOLTAGE")
      end
    end

    context "when the message name is :GET_DSRC_CONFIGURATION" do
      let(:name) { :GET_DSRC_CONFIGURATION }
      let(:body) { [0x00, 0x13, 0x7f, 0x00] }

      it "sets the client_id on the connection" do
        message_handler.handle(message)
        expect(connection).to have_received(:client_id=).with(4991)
      end
    end

    context "when the message name is not recognized" do
      let(:name) { :UNKNOWN_MESSAGE }

      it "does nothing" do
        expect { message_handler.handle(message) }.not_to raise_error
      end
    end

    context "when the message is GET_STATUS with HOST_COMM_ERROR" do
      let(:body) { "0100030400000004" }
      let(:message) { Chippy::Message.create(body) }

      it "does not raise a DeviceError" do
        expect { message_handler.handle(message) }.not_to raise_error
      end
    end

    context "when the message is GET_STATUS with DEVICE_REBOOTED" do
      let(:body) { "0100030400000008" }
      let(:message) { Chippy::Message.create(body) }

      it "does not raise a DeviceError" do
        expect { message_handler.handle(message) }.not_to raise_error
      end
    end

    context "when the message is GET_STATUS with other errors" do
      let(:body) { "0100030400000020" }
      let(:message) { Chippy::Message.create(body) }

      it "raises a DeviceError with the error message" do
        expect { message_handler.handle(message) }.to raise_error(Chippy::DeviceError, "[client_id: 1] Device errors: ERROR_INTERNAL_VOLTAGE")
      end
    end
  end
end
