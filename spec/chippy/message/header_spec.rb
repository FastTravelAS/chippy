require "spec_helper"

RSpec.describe Chippy::Message::Header do
  describe ".parse" do
    context "when given valid data" do
      it "parses the data correctly" do
        data = [1, 2, 3, 4]
        header = described_class.parse(data, type: :RESPONSE)
        expect(header.message_class).to eq :DEVICE_RESPONSE
        expect(header.message_name).to eq :GET_STATUS
        expect(header.message_id).to eq 3
        expect(header.message_length).to eq 4
      end
    end

    context "when given invalid data" do
      it "raises an ArgumentError" do
        expect { described_class.parse([]) }.to raise_error(ArgumentError)
      end
    end

    context "when given non-existent message id" do
      it "raises a MessageError" do
        data = [0, 0, 99, 0]
        expect { described_class.parse(data, type: :RESPONSE) }.to raise_error(Chippy::MessageError)
      end
    end

    context "when given non-existent message class" do
      it "raises a MessageError" do
        data = [99, 0, 0, 0]
        expect { described_class.parse(data, type: :RESPONSE) }.to raise_error(Chippy::MessageError)
      end
    end

    context "when given non-existent message response status" do
      it "raises a MessageError" do
        data = [0, 99, 0, 0]
        expect { described_class.parse(data, type: :RESPONSE) }.to raise_error(Chippy::MessageError)
      end
    end
  end

  describe "#to_a" do
    it "returns the data as an array" do
      data = [1, 2, 3, 4]
      header = described_class.parse(data, type: :REQUEST)
      expect(header.to_a).to eq data
    end
  end

  describe "#to_s" do
    it "returns the data as a string" do
      data = [1, 2, 3, 255]
      header = described_class.parse(data, type: :REQUEST)
      expect(header.to_s).to eq "010203ff"
    end
  end

  context "equality" do
    describe "==(other)" do
      it "is true when two headers with same data" do
        data = [1, 2, 3, 4]
        first_header = described_class.parse(data, type: :REQUEST)
        second_header = described_class.parse(data, type: :REQUEST)

        expect(first_header == second_header).to be_truthy
      end

      it "is false when two headers with same data" do
        first_data = [1, 2, 3, 4]
        second_data = [0, 0, 0, 0]
        first_header = described_class.parse(first_data, type: :REQUEST)
        second_header = described_class.parse(second_data, type: :REQUEST)

        expect(first_header == second_header).to be_falsey
      end
    end
  end
end
