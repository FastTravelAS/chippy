require "spec_helper"

RSpec.describe Chippy::MessageHandler do
  subject { described_class.new(connection) }

  let(:connection) { instance_double(Chippy::Connection) }

  describe "#handle" do
    let(:message) { instance_double(Chippy::Message, name: name, body: body, created_at: Time.now) }
    let(:name) { :CONNECT_TRANSPONDER_REPORT }
    let(:body) { "020201200e12345678ffff00000000" }

    before do
      allow(connection).to receive(:client_id).and_return(1)
      allow(connection).to receive(:client_id=)
      allow(connection).to receive(:request)
      allow(Chippy::ReadingJob).to receive(:perform_async)
    end

    context "when the message name is :CONNECT_TRANSPONDER_REPORT" do
      it "queues a ReadingJob with the chip, client_id, and created_at" do
        subject.handle(message)
        expect(Chippy::ReadingJob).to have_received(:perform_async).with("1", "12345678", a_kind_of(Float))
      end
    end

    context "when the message name is :KEEP_ALIVE" do
      let(:name) { :KEEP_ALIVE }

      it "sends a keepalive request" do
        subject.handle(message)
        expect(connection).to have_received(:request).with(an_instance_of(Chippy::Message))
      end
    end

    context "when the message name is :GET_STATUS" do
      let(:name) { :GET_STATUS }
      let(:body) { [0, 0, 0, 32] }

      it "raises a DeviceError with the error message" do
        expect { subject.handle(message) }.to raise_error(Chippy::DeviceError, "ERROR_INTERNAL_VOLTAGE")
      end
    end

    context "when the message name is :GET_DSRC_CONFIGURATION" do
      let(:name) { :GET_DSRC_CONFIGURATION }
      let(:body) { [0x00, 0x13, 0x7f, 0x00] }

      it "sets the client_id on the connection" do
        subject.handle(message)
        expect(connection).to have_received(:client_id=).with(4991)
      end
    end

    context "when the message name is not recognized" do
      let(:name) { :UNKNOWN_MESSAGE }

      it "does nothing" do
        expect { subject.handle(message) }.not_to raise_error
      end
    end
  end
end
