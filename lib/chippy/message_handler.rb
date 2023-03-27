module Chippy
  class MessageHandler
    include LoggerHelper
    CHIP_REGEXP = /020201200e(.*)ffff00000000/

    attr_reader :connection

    def initialize(connection)
      @connection = connection
    end

    def handle(message)
      log_message message
      name = message.name

      case name
      when :CONNECT_TRANSPONDER_REPORT
        handle_connect_transponder_report(message)
      when :KEEP_ALIVE
        handle_keep_alive(message)
      when :GET_STATUS
        handle_get_status(message)
      when :GET_DSRC_CONFIGURATION
        handle_get_dsrc_configuration(message)
      end
    end

    private

    def log_message(message)
      log(message, connection: connection, direction: :in)
    end

    def handle_connect_transponder_report(message)
      data = message.body.to_s
      chip = data.match(CHIP_REGEXP)[1]

      payload = {
        chip: chip,
        client_id: connection.client_id,
        timestamp: message.created_at.to_f
      }

      Chippy.producer.push(payload)
    end

    def handle_keep_alive(message)
      keep_alive_message = Message.create([0x00, 0x00], type: :REQUEST)
      connection.request(keep_alive_message)
    end

    def handle_get_status(message)
      data = message.body.to_a
      handle_get_status_response(data)
    end

    def handle_get_dsrc_configuration(message)
      data = message.body.to_a
      client_id = data[1..2]
      client_id = client_id.map { |b| b.to_s(16) }.join.hex
      connection.client_id = client_id
    end

    DEVICE_ERROR_MESSAGES = {
      CONFIGURATION_NOT_SET: 1,
      NO_APPLICATIONS_DEFINED: 2,
      HOST_COMM_ERROR: 4,
      DEVICE_REBOOTED: 8,
      ERROR_INTERNAL_VOLTAGE: 32,
      LOW_VOLTAGE_CLOCK_BATTERY: 64
    }

    def flag_set?(bitmask, flag)
      (bitmask & flag) == flag
    end

    def handle_get_status_response(data)
      device_status = data[3]
      errors = []
      DEVICE_ERROR_MESSAGES.each do |flag, bit|
        errors << flag if flag_set?(device_status, bit)
      end

      raise DeviceError.new(errors) unless errors.empty?
    end
  end
end
