module Chippy
  # HandshakeMessages is a helper class that provides arrays of byte sequences
  # representing the various messages used during the handshake process with a Chippy device.
  class HandshakeMessages
    class << self
      def all
        [
          operational_mode_non_transaction, # Set operational mode ( non-transaction )
          get_dsrc_configuration, # Get DSRC
          get_status, # Get transciever status
          set_beacon_time.call, # Set beacon time ( host time )
          *define_applications, # Define applications
          set_extended, # Set extended
          operational_mode_transaction # Set operational mode ( transaction )
        ]
      end

      private

      def operational_mode_non_transaction
        [0x01, 0x01, 0x00]
      end

      def get_dsrc_configuration
        [0x0e, 0x00]
      end

      def set_beacon_time
        -> { [0x0a, 0x04, *(Time.now.to_i.to_s(16).scan(/../).map { |x| x.to_i(16) })] }
      end

      def operational_mode_transaction
        [0x01, 0x01, 0x01]
      end

      def set_extended
        [0x3c, 0x01, 0x01]
      end

      def get_status
        [0x03, 0x00]
      end

      def define_applications
        context_marks = [[0xa4, 0, 2, 0, 5, 1], [0xa4, 0, 2, 0, 0x21, 1]]
        context_marks.map do |context_mark|
          [0x2c, # MsgID
            42, # MsgLength (number of bytes below)
            0, 6, # Sub message ID
            6, # ContextMarkLength
            *context_mark,
            0, 0, 0, 0, 0, 0, 0, 0, # ApplicationPassword, NewApplicationPassword
            2, # TransactionProfile
            0, # Key Location
            0, # Security
            0, 0, # MasterAccessCredentialsKeyNo
            0, # SystemElementSecurity
            0, 0, # Master System Element KeyNo
            0, # MasterAuthentication KeyReference_1
            0, # MasterAuthenticationLevel_1
            0, 0, # MasterAuthenticationKey_1
            0, # MasterAuthentication KeyReference_2
            0, # MasterAuthenticationLevel_2
            0, 0, # MasterAuthenticationKey_2
            0, # Options
            1, # AutomaticRead
            1, # No of Attributes
            0x20, # AttributeID 1
            0, # Authentication
            0, # AuthenticationCheck
            0, # AutomaticWrite
            0, # CloseTransaction
            0] # NoOfAttributes
        end
      end
    end
  end
end
