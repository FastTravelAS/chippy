module Chippy
  # Status is responsible for keeping track of the status of the Chippy server.
  class Status
    include LoggerHelper

    def initialize(pid)
      @pid = pid
      @client_status = {}
    end

    attr_reader :pid

    def inspect
      @client_status.inspect
    end

    def set_status_online
      log "Setting status to online"
      Chippy.redis.set(status_key, "online")
    end

    def set_status_offline
      log "Setting status to offline"
      Chippy.redis.set(status_key, "offline")
      Chippy.redis.del(instance_status_key)
      @client_status = {}
    end

    def set_client_status(client_id, status)
      @client_status[client_id] = status
      Chippy.redis.hset(instance_status_key, client_id, status)
    end

    def client_status(client_id)
      @client_status[client_id]
    end

    def client_initialized?(client_id)
      client_status(client_id).present? && Chippy.redis.hexists(instance_status_key, client_id)
    end

    def status_key
      "chippy:status".freeze
    end

    def instance_status_key
      "chippy:status:#{pid}".freeze
    end
  end
end
