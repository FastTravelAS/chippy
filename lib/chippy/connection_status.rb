module Chippy
  class ConnectionStatus
    attr_reader :client_id, :last_seen_at, :connected_at

    def initialize
      @connected_at = nil
      @client_id = nil
      @last_seen_at = nil
    end

    def connect(client_id)
      @client_id = client_id
      @connected_at = Time.now
    end

    def touch
      @last_seen_at = Time.now
    end

    def disconnect
      @client_id = nil
      @connected_at = nil
      @last_seen_at = nil
    end

    def disconnected?
      client_id.nil? && connected_at.nil?
    end
  end
end
