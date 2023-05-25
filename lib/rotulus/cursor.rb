require 'base64'

module Rotulus
  class Cursor
    class << self
      #  Initialize a Cursor instance for the given page instance and encoded token.
      #
      #  @param page [Page] Page instance
      #  @param token [String] Base64-encoded string data
      #  @return [Cursor] Cursor
      #
      #  @raise [InvalidCursor] if the token can't be decoded or if the cursor data was tampered.
      #  @raise [OrderChanged] if token generated from a page with a different `:order` definition.
      #  @raise [QueryChanged] if token generated from a page with a different `:ar_relation`.
      def for_page_and_token!(page, token)
        data = decode(token)
        reference_record = Record.new(page, data[:f])
        direction = data[:d]
        created_at = Time.at(data[:c]).utc
        cursor_state = data[:cs].presence
        order_state = data[:os].presence
        query_state = data[:qs].presence

        cursor = new(reference_record, direction, created_at: created_at)

        raise InvalidCursor if cursor.state != cursor_state

        if page.order_state != order_state
          raise OrderChanged if Rotulus.configuration.restrict_order_change?

          return nil
        end

        if page.query_state != query_state
          raise QueryChanged if Rotulus.configuration.restrict_query_change?

          return nil
        end

        cursor
      end

      #  Decode the given encoded cursor token
      #
      #  @param token [String] Encoded cursor token
      #  @return [Hash] Cursor data hash containing the cursor direction(:next, :prev),
      #    cursor's state, and the ordered column values of the reference record: last record
      #    of the previous page if page direction is `:next` or the first record of the next
      #    page if page direction is `:prev`.
      def decode(token)
        Oj.load(Base64.urlsafe_decode64(token))
      rescue ArgumentError, Oj::ParseError => e
        raise InvalidCursor.new("Invalid Cursor: #{e.message}")
      end

      #  Encode cursor data hash
      #
      #  @param token_data [Hash] Cursor token data hash
      #  @return token [String] String token for this cursor that can be used as param to Page#at.
      def encode(token_data)
        Base64.urlsafe_encode64(Oj.dump(token_data, symbol_keys: true))
      end
    end

    attr_reader :record, :direction, :created_at

    delegate :page, to: :record, prefix: false

    # @param record [Record] the last(first if direction is `:prev`) record of page containing
    #   the ordered column's values that will be used to generate the next/prev page query.
    # @param direction [Symbol] the cursor direction, `:next` for next page or `:prev` for
    #   previous page
    # @param created_at [Time] only needed when deserializing a Cursor from a token. The time
    #   when the cursor was last initialized. see Cursor.from_page_and_token!
    def initialize(record, direction, created_at: nil)
      @record = record
      @direction = direction.to_sym
      @created_at = created_at.presence || Time.current

      validate!
    end

    # @return [Boolean] returns true if the cursor should retrieve the 'next' records from the last
    #   record of the previous page. Otherwise, returns false.
    def next?
      direction == :next
    end

    # @return [Boolean] returns true if the cursor should retrieve the 'previous' records from the
    #   first record of a page. Otherwise, returns false.
    def prev?
      !next?
    end

    # Generate the SQL condition to filter the records of the next/previous page. The condition is
    # generated based on the order definition and the referenced record's values.
    #
    # @return [String] the SQL 'where' condition to get the next or previous page's records.
    def sql
      @sql ||= Arel.sql(record.sql_seek_condition(direction))
    end

    # Generate the token: a Base64-encoded string representation of this cursor
    #
    # @return [String] the token encoded in Base64.
    def to_token
      @token ||= self.class.encode(f: record.values,
                                   d: direction,
                                   c: created_at.to_i,
                                   cs: state,
                                   os: page.order_state,
                                   qs: page.query_state)
    end
    alias to_s to_token

    # Generate a 'state' string for integrity checking of the reference record, direction,
    # and created_at data from a decoded Cursor token.
    #
    # @return [String] the hashed state
    def state
      state_data = "#{record.state}#{direction}#{created_at.to_i}#{secret}"

      Digest::MD5.hexdigest(state_data)
    end

    # Checks if the cursor is expired
    #
    # @return [Boolean] returns true if cursor is expired
    def expired?
      return false if config.token_expires_in.nil? || created_at.nil?

      (created_at + config.token_expires_in) < Time.current
    end

    private

    # Checks whether the cursor is valid
    #
    # @return [Boolean]
    #
    # @raise [InvalidCursorDirection] if the cursor direction is not valid.
    # @raise [ExpiredCursor] if the cursor is expired.
    def validate!
      raise ExpiredCursor.new('Cursor token expired') if expired?

      return if direction_valid?

      raise InvalidCursorDirection.new('Cursor direction should either be :prev or :next.')
    end

    def direction_valid?
      %i[prev next].include?(direction)
    end

    def secret
      return config.secret if config.secret.present?

      raise ConfigurationError.new('missing :secret configuration.')
    end

    def config
      @config ||= Rotulus.configuration
    end
  end
end
