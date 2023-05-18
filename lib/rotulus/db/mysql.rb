module Rotulus
  module DB
    class MySQL < Database
      def select_all_sql(table_name)
        "`#{table_name}`.*"
      end

      def nulls_order_sql(nulls)
        return 'is not null' if nulls == :first

        'is null'
      end

      def nullable_order_sql(column_name, sort_direction, nulls)
        sql = order_sql(column_name, sort_direction)
        return sql if nulls_in_default_order?(sort_direction, nulls)

        "#{column_name} #{nulls_order_sql(nulls)}, #{sql}"
      end

      def reversed_nullable_order_sql(column_name, sort_direction, nulls)
        sql = reversed_order_sql(column_name, sort_direction)

        nulls = reverse_nulls(nulls)
        return sql if nulls_in_default_order?(reverse_sort_direction(sort_direction), nulls)

        "#{column_name} #{nulls_order_sql(nulls)}, #{sql}"
      end
    end
  end
end
