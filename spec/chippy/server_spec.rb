require "spec_helper"

RSpec.describe Chippy::Server do
  let!(:concurrency) { 5 }
  let!(:port) { 0 }
  let!(:server) { Chippy::Server.new(port, concurrency: concurrency) }
  let(:connection) { instance_double(Chippy::Connection, client_id: "test_client_id") }
  let(:message_handler) { instance_double(Chippy::MessageHandler) }
  let(:handshake) { instance_double(Chippy::Handshake) }
  let(:connection_status) { instance_double(Chippy::ConnectionStatus, connected_at: 4.hours.ago, last_seen_at: 10.minutes.ago) }

  before do
    allow(Chippy::Connection).to receive(:new).and_return(connection)
    allow(Chippy::MessageHandler).to receive(:new).and_return(message_handler)
    allow(Chippy::Handshake).to receive(:new).and_return(handshake)
    allow(connection).to receive(:read)
    allow(connection).to receive(:close)
    allow(handshake).to receive(:perform)
    allow(connection_status).to receive(:touch)
    server.connections["test_client_id"] = connection_status
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
      expect(connection).to have_received(:close)
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

    it "logs and closes the connection on MessageError" do
      allow(connection).to receive(:read).and_raise(Chippy::MessageError)
      allow(server).to receive(:log_error)

      server.handle_connection(connection)

      expect(server).to have_received(:log_error)
      expect(connection).to have_received(:close)
    end

    it "handles multiple messages in sequence" do
      # Set up your test server and connection
      server = Chippy::Server.new(port, concurrency: 1)
      connection = instance_double(Chippy::Connection)
      server.connections["test_client_id"] = Chippy::ConnectionStatus.new

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
      expect(server).to have_received(:log).with("Started chip reader server on port #{port}")
      expect(server).to have_received(:spawn_thread).exactly(concurrency).times
      expect(server).to have_received(:sleep)
    end

    it "rescues Interrupt and calls exit with 0" do
      allow(server).to receive(:sleep).and_raise(Interrupt)

      server.run

      expect(server).to have_received(:exit).with(0)
    end
  end
end
