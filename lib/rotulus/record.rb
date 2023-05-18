module Rotulus
  class Record
    attr_reader :page, :values

    # Creates a new Record instance representing the first or last record of a :page
    # wherein the :values include the ordered column values of the AR record. This
    # instance serves as the reference point in generating the SQL query to fetch the the page's
    # previous or next page's records. That is, the first record's values of a page are used
    # in the WHERE condition to fetch the previous page's records and the last record's values
    # are used to fetch next page's records.
    #
    # @param page [Rotulus::Page] the Page instance
    # @param values [Hash] the ordered column values of an AR record
    def initialize(page, values = {})
      @page = page
      @values = normalize_values(values || {})
    end

    # Get the records preceding or succeeding this record in respect to the sort direction of
    # the ordered columns.
    #
    # @param direction [Symbol] `:next` to fetch succeeding records otherwise, `:prev`.
    #
    # @return [String] SQL 'where' condition
    def sql_seek_condition(direction)
      page.order_columns.reverse.reduce(nil) do |sql, column|
        column_seek_sql = ColumnConditionBuilder.new(
          column,
          values[column.prefixed_name],
          direction,
          sql
        ).build

        parenthesize = !sql.nil? && !column.leftmost?
        parenthesize ? "(#{column_seek_sql})" : column_seek_sql
      end.squish
    end

    # Generate a 'state' so we can detect whether the record values changed/
    # for integrity check. e.g. Record values prior to encoding in the cursor
    # vs. the decoded values from an encoded cursor token.
    #
    # @return [String] the hashed state
    def state
      Digest::MD5.hexdigest(values.map { |k, v| "#{k}:#{v}" }.join('~'))
    end

    private

    # Normalize values so that serialization-deserialization behaviors(e.g. values from/to encoded
    # cursor data, SQL query generation) are predictable:
    # 1. Date, Time, Datetime: iso8601 formatted
    # 2. Float: converted to BigDecimal
    def normalize_values(values)
      values.transform_values! do |v|
        v = v.utc if v.respond_to?(:utc)
        if v.respond_to?(:iso8601)
          v = v.method(:iso8601).arity.zero? ? v.iso8601 : v.iso8601(6)
        end

        v = BigDecimal(v.to_s) if v.is_a?(Float)
        v
      end
    end
  end
end
