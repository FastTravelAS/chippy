require "spec_helper"

RSpec.describe Chippy::Message::Body do
  describe ".parse" do
    it "returns a new body object with the data from the hex string" do
      body = described_class.parse [1, 2, 3]
      expect(body.data).to eq [1, 2, 3]
    end
  end

  describe "#to_a" do
    it "returns the body data as an array" do
      body = described_class.new([1, 2, 3])
      expect(body.to_a).to eq [1, 2, 3]
    end
  end

  describe "#to_s" do
    it "returns a string representation of the body data" do
      body = described_class.new([255, 255, 255])
      expect(body.to_s).to eq "ffffff"
    end
  end

  context "when comparing equality" do
    describe "==(other)" do
      it "is true when two bodies with same data" do
        data = [1, 2, 3]
        first_body = described_class.parse(data, type: :REQUEST)
        second_body = described_class.parse(data, type: :REQUEST)

        expect(first_body == second_body).to be_truthy
      end

      it "is false when comparing two different bodies" do
        first_data = [1, 2, 3]
        second_data = [255, 255, 255]
        first_header = described_class.parse(first_data, type: :REQUEST)
        second_header = described_class.parse(second_data, type: :REQUEST)

        expect(first_header == second_header).to be_falsey
      end
    end
  end
end
