module Rotulus
  module DB
    class Database
      def name
        @name ||= self.class.name.split('::').last.downcase
      end

      def select_all_sql(table_name)
        "\"#{table_name}\".*"
      end

      def nulls_order_sql(nulls)
        return 'nulls first' if nulls == :first

        'nulls last'
      end

      def order_sql(column_name, sort_direction)
        "#{column_name} #{sort_direction}"
      end

      def reversed_order_sql(column_name, sort_direction)
        "#{column_name} #{reverse_sort_direction(sort_direction)}"
      end

      def nullable_order_sql(column_name, sort_direction, nulls)
        sql = order_sql(column_name, sort_direction)
        return sql if nulls_in_default_order?(sort_direction, nulls)

        "#{sql} #{nulls_order_sql(nulls)}"
      end

      def reversed_nullable_order_sql(column_name, sort_direction, nulls)
        sql = reversed_order_sql(column_name, sort_direction)

        nulls = reverse_nulls(nulls)
        return sql if nulls_in_default_order?(reverse_sort_direction(sort_direction), nulls)

        "#{sql} #{nulls_order_sql(nulls)}"
      end

      def nulls_in_default_order?(sort_direction, nulls)
        nulls == default_nulls_order(sort_direction)
      end

      # SQLite and MySQL considers NULL values to be smaller than any other values.
      # https://www.sqlite.org/lang_select.html#orderby
      # https://dev.mysql.com/doc/refman/8.0/en/working-with-null.html
      def default_nulls_order(sort_direction)
        return :first if sort_direction == :asc

        :last
      end

      private

      def reverse_sort_direction(sort_direction)
        sort_direction == :asc ? :desc : :asc
      end

      def reverse_nulls(nulls)
        nulls == :first ? :last : :first
      end
    end
  end
end
