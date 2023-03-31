require "spec_helper"

RSpec.describe Chippy::LogWriter do
  let(:mock_logger) { double }

  before do
    allow(Chippy).to receive(:logger).and_return(mock_logger)
  end

  describe "#log" do
    it "writes the message to the log with the specified tags" do
      message = "test message"
      tags = %w[tag1 tag2]
      allow(mock_logger).to receive(:tagged).with(tags).and_return(mock_logger)
      allow(mock_logger).to receive(:info).with(/test message/)

      described_class.new(mock_logger).log(message, tags)

      expect(mock_logger).to have_received(:tagged).with(tags)
      expect(mock_logger).to have_received(:info).with(/test message/)
    end
  end

  describe "#log_error" do
    it "writes the error to the log with the specified tags" do
      error = StandardError.new("test error")
      tags = %w[tag1 tag2]
      allow(mock_logger).to receive(:tagged).with(tags).and_return(mock_logger)
      allow(mock_logger).to receive(:error).with(/test error/)

      described_class.new(mock_logger).log_error(error, tags)

      expect(mock_logger).to have_received(:tagged).with(tags)
      expect(mock_logger).to have_received(:error).with(/test error/)
    end
  end
end
