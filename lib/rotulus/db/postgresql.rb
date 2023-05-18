module Rotulus
  module DB
    class PostgreSQL < Database
      # PG considers NULL values to be larger than any other values.
      # https://www.postgresql.org/docs/current/queries-order.html
      def default_nulls_order(sort_direction)
        return :last if sort_direction == :asc

        :first
      end
    end
  end
end
