require "spec_helper"

RSpec.describe Chippy::Message do
  describe ".create" do
    it "instantiates Header and Body" do
      message = described_class.create("0000000100")
      expect(message.header).to be_instance_of Chippy::Message::Header
      expect(message.body).to be_instance_of Chippy::Message::Body
    end

    describe "when given a binary string" do
      it "creates a new Message instance" do
        message = described_class.create("\x00\x01\x02\x03")
        expect(message).to be_a(described_class)
        expect(message.header.to_s).to eq "00010203"
      end
    end

    describe "when given a hex-encoded string" do
      it "creates a new Message instance" do
        message = described_class.create("01020304")
        expect(message).to be_a(described_class)
        expect(message.header.to_s).to eq "01020304"
      end

      it "creates a new Message instance if type request" do
        message = described_class.create("0000", type: :REQUEST)
        expect(message).to be_a(described_class)
        expect(message.header.to_s).to eq "0000"
      end
    end

    describe "when given an array of hex-encoded strings" do
      it "creates a new Message instance" do
        message = described_class.create(%w[01 02 03 04])
        expect(message).to be_a(described_class)
        expect(message.header.to_s).to eq "01020304"
      end
    end

    describe "when given an array of integers" do
      it "creates a new Message instance" do
        message = described_class.create([1, 2, 3, 4])
        expect(message).to be_a(described_class)
        expect(message.header.to_s).to eq "01020304"
      end
    end

    describe "when given an invalid array" do
      it "raises an ArgumentError" do
        expect { described_class.create([1, "02", 3, "04"]) }.to raise_error(ArgumentError)
      end
    end

    describe "when given an invalid data type" do
      it "raises an ArgumentError" do
        expect { described_class.create(:invalid) }.to raise_error(ArgumentError)
      end
    end
  end

  describe ".split_data" do
    it "takes a byte array and returns two arrays split at content length position" do
      byte_array = %w[02 00 17 04 ff ff ff ff]
      header, body = described_class.split_data(byte_array, :RESPONSE)
      expect(header).to eq %w[02 00 17 04]
      expect(body).to eq %w[ff ff ff ff]
    end
  end

  context "when doing conversions" do
    let(:message) { described_class.create([0, 0, 0, 1, 255]) }

    describe "#to_a" do
      it "returns the message data in array" do
        expect(message.to_a).to eq [0, 0, 0, 1, 255]
      end
    end

    describe "#to_s" do
      it "returns whole payload" do
        expect(message.full_message).to eq "\x00\x00\x00\x01\xFF".force_encoding("ASCII-8BIT")
      end
    end

    describe "#to_h" do
      it "returns the message data in hash" do
        expect(message.to_h).to include({content: "00000001ff", created_at: a_kind_of(Float), full_message: "\x00\x00\x00\x01\xFF".force_encoding("ASCII-8BIT"), id: 0, klass: :KEEP_ALIVE, length: 1, name: :KEEP_ALIVE, status: :OK})
      end
    end
  end

  context "with message methods" do
    let!(:time) { Time.now }
    let(:message) { Timecop.freeze(time) { described_class.create(%w[02 00 17 01 01]) } }

    describe "#message_class" do
      it "returns the type of message" do
        expect(message.message_class).to eq :DEVICE_REPORT
      end
    end

    describe "#status" do
      it "returns the message report status" do
        expect(message.status).to eq :OK
      end
    end

    describe "#message_id" do
      it "reads header and returns the message id" do
        expect(message.message_id).to eq 23
      end
    end

    describe "#name" do
      it "reads header and returns the message name" do
        expect(message.name).to eq :CONNECT_TRANSPONDER_REPORT
      end
    end

    describe "#message_length" do
      it "reads header and returns the message length" do
        expect(message.message_length).to eq 1
      end
    end

    describe "#inspect" do
      it "returns pertinent information about the message" do
        expect(message.inspect).to eq "Message(CONNECT_TRANSPONDER_REPORT - status: OK - length: 1 - content: 0200170101)"
      end
    end

    describe "#created_at" do
      it "returns timestamp from when it's created" do
        expect(message.created_at.to_f).to eq time.to_f
      end
    end
  end

  context "with message requests" do
    describe ".create" do
      it "returns a message of type :REQUEST" do
        data = "0200"
        message = described_class.create(data, type: :REQUEST)
        expect(message.type).to eq :REQUEST
      end

      it "returns a header with correct mapping" do
        data = "0200"
        message = described_class.create(data, type: :REQUEST)
        expect(message.header.message_id).to eq 2
        expect(message.header.status).to eq :OK
      end
    end
  end

  context "when doing message validation" do
    let(:valid_message) { described_class.create(%w[02 00 17 01 01]) }
    let(:invalid_message) { described_class.create(%w[02 00 17 01 01 01]) }
    let(:timeout_message) { described_class.create(%w[01 13 01 00]) }
    let(:not_ok_message) { described_class.create(%w[02 11 17 01]) }

    describe "#ok?" do
      it "returns true when ok?" do
        expect(valid_message).to be_ok
      end

      it "returns true when timeout_error" do
        expect(timeout_message).to be_ok
      end

      it "returns false if missing body" do
        expect(described_class.new(header: Chippy::Message::Header.new(%w[02 00 17 01]))).not_to be_ok
      end

      it "returns false if body is of the wrong length" do
        expect(invalid_message).not_to be_ok
      end

      it "returns false if status is other than ok" do
        expect(not_ok_message).not_to be_ok
      end
    end
  end
end
