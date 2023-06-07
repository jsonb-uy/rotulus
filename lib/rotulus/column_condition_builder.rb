module Rotulus
  class ColumnConditionBuilder
    # Generates a condition builder instance that builds an SQL condition
    # to filter the preceding or succeeding records given a Column instance and its
    # value.
    #
    # @param column [Rotulus::Column] ordered column
    # @param value [Object] the column value for a specific reference record
    # @param direction [Symbol] the seek direction, `:next` or `:prev`
    # @param tie_breaker_sql [Symbol] in case :column is not distinct, a 'tie-breaker' SQL
    #  condition is needed to ensure stable pagination. This condition is generated from the (distinct)
    #  columns with lower precedence in the ORDER BY column list. For example, in
    #  "ORDER BY first_name asc, ssn desc", multiple records may exist with the same 'first_name' value.
    #  The distinct column 'ssn' in the order definition will be the tie-breaker. If no
    #  distinct column is defined in the order definition, the PK will be the tie-breaker.
    def initialize(column, value, direction, tie_breaker_sql = nil)
      @column = column
      @value = value
      @direction = direction
      @tie_breaker_sql = tie_breaker_sql
    end

    def build
      return filter_condition unless column.nullable?

      nullable_filter_condition
    end

    private

    attr_reader :column, :value, :direction, :tie_breaker_sql
    delegate :nulls_first?, :nulls_last?, to: :column, prefix: false

    def filter_condition
      return seek_condition if column.distinct?

      prefilter("#{seek_condition} OR (#{tie_break(identity)})")
    end

    def nullable_filter_condition
      return seek_to_null_direction_condition if seek_to_null_direction?
      return filter_condition unless value.nil?

      "#{not_null_condition} OR (#{tie_break(null_condition)})"
    end

    def seek_to_null_direction_condition
      return tie_break null_condition if value.nil?

      condition = "#{seek_condition} OR #{null_condition}"
      return condition if column.distinct?

      prefilter("(#{condition}) OR (#{tie_break(identity)})")
    end

    def identity
      "#{column.prefixed_name} = #{quoted_value}"
    end

    # Pre-filter leftmost ordered column for perfomance if column is non-distinct
    # https://use-the-index-luke.com/sql/partial-results/fetch-next-page#sb-equivalent-logic
    def prefilter(condition)
      return condition unless column.leftmost?

      if column.nullable? && seek_to_null_direction?
        return "(#{seek_condition(:inclusive)} OR #{null_condition}) AND (#{condition})"
      end

      "#{seek_condition(:inclusive)} AND (#{condition})"
    end

    def tie_break(condition)
      return condition if tie_breaker_sql.blank?

      "#{condition} AND #{tie_breaker_sql}"
    end

    def null_condition
      "#{column.prefixed_name} IS NULL"
    end

    def not_null_condition
      "#{column.prefixed_name} IS NOT NULL"
    end

    def seek_condition(inclusivity = :exclusive)
      operator = seek_operators[direction][column.direction]
      operator = "#{operator}=" if inclusivity == :inclusive

      "#{column.prefixed_name} #{operator} #{quoted_value}"
    end

    def seek_operators
      @seek_operators ||= { next: { asc: '>', desc: '<' },
                            prev: { asc: '<', desc: '>' } }
    end

    def seek_next?
      direction == :next
    end

    def seek_prev?
      !seek_next?
    end

    def seek_to_null_direction?
      (nulls_first? && seek_prev?) || (nulls_last? && seek_next?)
    end

    def quoted_value
      return value unless value.is_a?(String)

      ActiveRecord::Base.connection.quote(value)
    end
  end
end
