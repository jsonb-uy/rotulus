module Rotulus
  class PageTableizer
    def initialize(page)
      @page = page
    end

    # Returns a string showing the page's records in table form with the ordered columns
    # as the columns. Some data types are formatted so output is consistent regardless of the
    # DB engine in use:
    #  1. Datetime - iso8601(3) formatted
    #  2. Float - converted to BigDecimal before converting to string
    #  3. Float/BigDecimal - '.0' fractional portion is dropped
    #  4. Nil - <NULL>
    #
    # @return [String] table
    #
    # example:
    #   +-----------------------------------------------------------------------------------------+
    #   |   users.first_name   |   users.last_name   |        users.email         |   users.id    |
    #   +-----------------------------------------------------------------------------------------+
    #   |        George        |       <NULL>        |     george@domain.com      |      1        |
    #   |         Jane         |        Smith        |   jane.c.smith@email.com   |      2        |
    #   |         Jane         |         Doe         |     jane.doe@email.com     |      3        |
    #   +-----------------------------------------------------------------------------------------+
    #
    def tableize
      return '' if records.blank?

      s = ''
      s << divider
      s << header
      s << divider
      s << records.map { |record| record_to_string(record) }.join("\n")
      s << "\n"
      s << divider
      s
    end

    private

    attr_reader :page

    def order
      @order ||= page.order
    end

    def records
      @records ||= page.records
    end

    def columns
      @columns ||= order.prefixed_column_names
    end

    def col_padding
      1
    end

    def col_widths
      return @col_widths if instance_variable_defined?(:@col_widths)

      @col_widths = columns.each_with_object({}) { |name, h| h[name] = name.size + (col_padding * 2) }
      records.each do |record|
        values = order.selected_values(record)

        values.each do |col_name, value|
          width = normalize_value(value).size + (col_padding * 2)

          @col_widths[col_name] = width if @col_widths[col_name] <= width
        end
      end

      @col_widths
    end

    def header
      @header ||= columns.reduce('') do |names, name|
        "#{names}|#{name.center(col_widths[name])}"
      end + " |\n"
    end

    def divider
      @divider ||= '+' + ('-' * (header.size - 3)) + "+\n"
    end

    def record_to_string(record)
      values = order.selected_values(record)
      s = values.each_with_object('') do |(k, v), s|
        v = normalize_value(v)
        s << "|#{v.center(col_widths[k])}"
      end

      s << ' |'
    end

    def normalize_value(value)
      return '<NULL>' if value.nil?
      return "'#{value}'" if value.blank? && value.is_a?(String)

      value = if Rotulus.db.name == 'sqlite'
                format_sqlite_value(value)
              else
                format_value(value)
              end

      value = value.to_s if value.is_a?(BigDecimal)
      value = BigDecimal(value.to_s).to_s if value.is_a?(Float)
      value = value.split('.').first if value.is_a?(String) && value =~ /^\-?\d+\.0$/ # drop decimal if it's 0

      value.to_s
    end

    def format_sqlite_value(value)
      return value unless value.is_a?(String)

      date_pattern1 = /^\d{4}\-\d{2}\-\d{2} \d{2}:\d{2}:\d{2}\.\d{6}$/
      date_pattern2 = /^\d{4}\-\d{2}\-\d{2} \d{2}:\d{2}:\d{2}$/

      if value =~ date_pattern1
        return DateTime.strptime(value, '%Y-%m-%d %H:%M:%S.%L')
                       .utc
                       .iso8601(3)
                       .gsub('+00:00', 'Z')
      elsif value =~ date_pattern2
        return DateTime.strptime(value, '%Y-%m-%d %H:%M:%S')
                       .utc
                       .iso8601(3)
                       .gsub('+00:00', 'Z')
      end

      value
    end

    def format_value(value)
      value = value.utc if value.respond_to?(:utc)
      if value.respond_to?(:iso8601)
        value = value.method(:iso8601).arity.zero? ? value.iso8601 : value.iso8601(3)
      end

      value
    end
  end
end
