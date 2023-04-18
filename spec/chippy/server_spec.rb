require "spec_helper"

RSpec.describe Chippy::Server do
  let!(:concurrency) { 5 }
  let!(:port) { 0 }
  let!(:hostname) { "localhost" }
  let!(:server) { described_class.new(port: port, hostname: hostname, concurrency: concurrency) }
  let(:connection) { instance_double(Chippy::Connection, client_id: "test_client_id") }
  let(:message_handler) { instance_double(Chippy::MessageHandler) }
  let(:handshake) { instance_double(Chippy::Handshake) }

  before do
    allow(Chippy::Connection).to receive(:new).and_return(connection)
    allow(Chippy::MessageHandler).to receive(:new).and_return(message_handler)
    allow(Chippy::Handshake).to receive(:new).and_return(handshake)
    allow(connection).to receive(:read)
    allow(connection).to receive(:close)
    allow(handshake).to receive(:perform)
  end

  after do
    server.try(:close)
  end

  describe "#trap_signals" do
    it "traps INT" do
      allow(server).to receive(:trap)
      server.trap_signals
      expect(server).to have_received(:trap).with("INT")
    end

    it "traps TERM" do
      allow(server).to receive(:trap)
      server.trap_signals
      expect(server).to have_received(:trap).with("TERM")
    end
  end

  describe "#handle_exit" do
    it "traps at_exit and performs the correct actions" do
      allow(server).to receive(:at_exit).and_yield
      allow(server).to receive(:log).with(a_kind_of(String))
      allow(server).to receive(:close)

      server.handle_exit

      expect(server).to have_received(:log).with("Shutting down server")
      expect(server).to have_received(:close).once
    end
  end

  describe "#handle_connection" do
    it "creates a new message handler" do
      allow(Chippy::MessageHandler).to receive(:new).with(connection)
      server.handle_connection(connection)
      expect(Chippy::MessageHandler).to have_received(:new).with(connection)
    end

    it "starts the normal loop" do
      server.handle_connection(connection)

      expect(connection).to have_received(:read)
    end

    it "handles incoming messages" do
      message = Chippy::Message.create(%w[02 00 17 01 01])
      allow(connection).to receive(:read).and_return(message, nil)
      allow(message_handler).to receive(:handle).with(message)

      server.handle_connection(connection)

      expect(connection).to have_received(:read).twice
      expect(message_handler).to have_received(:handle).with(message).once
    end

    it "logs and closes the connection on EOFError" do
      allow(connection).to receive(:read).and_raise(EOFError)
      allow(server).to receive(:log_error)

      server.handle_connection(connection)

      expect(server).to have_received(:log_error)
      expect(connection).to have_received(:close)
    end

    it "logs on MessageError" do
      allow(connection).to receive(:read).and_raise(Chippy::MessageError)
      allow(server).to receive(:log_error)

      server.handle_connection(connection)

      expect(server).to have_received(:log_error)
    end

    it "handles multiple messages in sequence" do
      # Set up your test server and connection
      server = described_class.new(port: port, concurrency: 1)
      connection = instance_double(Chippy::Connection)

      allow(connection).to receive(:client_id).and_return("test_client_id")
      allow(connection).to receive(:close)

      # Set up a test message sequence and a message handler
      test_data = %w[01000000 02000000 03000000]
      test_messages = test_data.map { |data| Chippy::Message.create(data) }
      message_handler = instance_double(Chippy::MessageHandler)

      # Stub the connection to return messages in sequence
      allow(connection).to receive(:read).and_return(*test_messages, nil)
      allow(Chippy::MessageHandler).to receive(:new).with(connection).and_return(message_handler)
      allow(message_handler).to receive(:handle)

      # Call the handle_connection method with a custom behavior that counts the handled messages
      handled_message_count = 0
      server.handle_connection(connection) do
        handled_message_count += 1
      end

      # Assert that the server handled the correct number of messages and called the handler for each message
      expect(handled_message_count).to eq(test_messages.size)
      test_messages.each do |message|
        expect(message_handler).to have_received(:handle).with(message).once
      end
    end
  end

  describe "#run" do
    before do
      allow(server).to receive(:trap_signals)
      allow(server).to receive(:handle_exit)
      allow(server).to receive(:log).with(a_kind_of(String))
      allow(server).to receive(:spawn_thread).and_return(Thread.new {})
      allow(server).to receive(:sleep)
      allow(server).to receive(:exit)
    end

    it "calls the necessary methods and spawns the correct number of threads" do
      server.run

      expect(server).to have_received(:trap_signals)
      expect(server).to have_received(:handle_exit)
      expect(server).to have_received(:log).with("Started chip reader server on #{hostname}:#{port}")
      expect(server).to have_received(:spawn_thread).exactly(concurrency).times
      expect(server).to have_received(:sleep)
    end

    it "rescues Interrupt and calls exit with 0" do
      allow(server).to receive(:sleep).and_raise(Interrupt)

      server.run

      expect(server).to have_received(:exit).with(0)
    end
  end

  describe "handling malformed messages" do
    let(:socket) { instance_double(UNIXSocket) }
    let(:connection) { Chippy::Connection.new(socket, "test_client_id") }

    it "discards the correct number of bytes from the connection" do
      # Mock the connection read method to raise Chippy::MessageError with the correct remaining_data_length
      allow(connection).to receive(:read).and_raise(Chippy::MalformedMessageError.new(remaining_data_length: 7))

      allow(socket).to receive(:read).with(7)

      server.handle_connection(connection)

      # Check that the read method has been called with the correct remaining data length
      expect(socket).to have_received(:read).with(7).once
    end
  end

  describe "IOError" do
    let(:socket) { instance_double(UNIXSocket) }
    let(:connection) { Chippy::Connection.new(socket, "test_client_id") }

    it "logs the error" do
      allow(connection).to receive(:read).and_raise(IOError)
      allow(server).to receive(:log_error)

      server.handle_connection(connection)

      expect(server).to have_received(:log_error)
    end
  end
end
