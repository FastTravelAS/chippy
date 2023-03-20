require "spec_helper"

RSpec.describe Chippy::ConnectionStatus do
  let(:connection_status) { described_class.new }

  describe "#connect" do
    it "sets the client_id and connected_at attributes" do
      client_id = "1234"
      connection_status.connect(client_id)

      expect(connection_status.client_id).to eq(client_id)
      expect(connection_status.connected_at).to be_a(Time)
    end
  end

  describe "#touch" do
    it "sets the last_seen_at attribute" do
      connection_status.touch

      expect(connection_status.last_seen_at).to be_a(Time)
    end

    it "updates the last_seen_at attribute" do
      connection_status.touch
      first_seen_at = connection_status.last_seen_at

      Timecop.freeze(1.hour.from_now) do
        connection_status.touch
      end

      expect(connection_status.last_seen_at).to be > first_seen_at
    end
  end

  describe "#disconnect" do
    it "resets the client_id and connected_at attributes" do
      connection_status.connect("1234")
      connection_status.disconnect

      expect(connection_status.client_id).to be_nil
      expect(connection_status.connected_at).to be_nil
    end
  end

  describe "#disconnected?" do
    it "returns true when not connected" do
      connection_status.disconnect

      expect(connection_status.disconnected?).to be(true)
    end

    it "returns false when connected" do
      connection_status.connect("1234")

      expect(connection_status.disconnected?).to be(false)
    end
  end
end
