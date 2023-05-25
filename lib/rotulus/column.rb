module Rotulus
  class Column
    attr_reader :model, :name, :direction, :nulls

    # Creates a Column object representing a table column in the "ORDER BY" expression.
    #
    # @param model [Class] the ActiveRecord model class name where this column belongs
    # @param name [String] the column name. Columns from joined tables are
    #   prefixed with the joined table's name/alias (e.g. +some_table.column+).
    # @param direction [Symbol] the sort direction, +:asc+ or +:desc+. Default: +:asc+.
    # @param nullable [Boolean] whether a null value is expected for this column in the result.
    #  Note that for queries with table JOINs, a column could have a null value even
    #  if the column doesn't allow nulls in its table so :nullable might need to be set
    #  to +true+ for such cases.
    #  Default: +true+ if :nullable option value is nil and the column is defined as
    #  nullable in its table otherwise, false.
    # @param nulls [Symbol] null values sorting, +:first+ for +NULLS FIRST+ and
    #  +:last+ for +NULLS LAST+. Applicable only if column is nullable.
    # @param distinct [Boolean] whether the column value is expected to be unique in the result.
    #  Note that for queries with table JOINs, multiple rows could have the same column
    #  value even if the column has a unique index defined in its table so :distinct might
    #  need to be set to +false+ for such cases.
    #  Default: true if :distinct option value is nil and the column is the PK of its
    #  table otherwise, false.
    #
    def initialize(model, name, direction: :asc, nullable: nil, nulls: nil, distinct: nil)
      @model = model
      @name = name.to_s
      unless name_valid?
        raise Rotulus::InvalidColumn.new("Column/table name must contain letters, digits (0-9), or \
          underscores and must begin with a letter or underscore.".squish)
      end

      @direction = direction.to_s.downcase == 'desc' ? :desc : :asc
      @distinct = (distinct.nil? ? primary_key? : distinct).presence || false
      @nullable = (nullable.nil? ? metadata&.null : nullable).presence || false
      @nulls = nulls_order(nulls)
    end

    def self.select_alias_to_name(select_alias)
      select_alias.gsub('cursor___', '').gsub('__', '.')
    end

    def self.select_alias(name)
      "cursor___#{name.to_s.gsub('.', '__')}"
    end

    # Mark the column as the 'leftmost' column in the 'ORDER BY' SQL (column with highest sort priority)
    def as_leftmost!
      @leftmost = true

      self
    end

    def leftmost?
      @leftmost
    end

    def asc?
      direction == :asc
    end

    def desc?
      !asc?
    end

    def distinct?
      @distinct
    end

    def nullable?
      @nullable
    end

    def nulls_first?
      nulls == :first
    end

    def nulls_last?
      nulls == :last
    end

    def unprefixed_name
      @unprefixed_name ||= name.split('.').last
    end

    def prefixed_name
      @prefixed_name ||= if !name_has_prefix?
                           "#{model.table_name}.#{name}"
                         else
                           name
                         end
    end

    def select_alias
      self.class.select_alias(prefixed_name)
    end

    def to_h
      h = {
        direction: direction,
        nullable: nullable?,
        distinct: distinct?
      }
      h[:nulls] = nulls if nullable?

      { prefixed_name => h }
    end

    def reversed_order_sql
      return Rotulus.db.reversed_order_sql(prefixed_name, direction) unless nullable?

      Rotulus.db.reversed_nullable_order_sql(prefixed_name, direction, nulls)
    end

    def order_sql
      return Rotulus.db.order_sql(prefixed_name, direction) unless nullable?

      Rotulus.db.nullable_order_sql(prefixed_name, direction, nulls)
    end

    def select_sql
      "#{prefixed_name} as #{select_alias}"
    end

    private

    def metadata
      model.columns_hash[unprefixed_name]
    end

    def name_has_prefix?
      return @name_has_prefix if instance_variable_defined?(:@name_has_prefix)

      @name_has_prefix = name.include?('.')
    end

    # Only alphanumeric columns and with or without underscores and table/alias prefix are allowed.
    def name_valid?
      return false if name.blank?

      !!(name =~ /^([[:alpha:]_][[:alnum:]_]*)(\.([[:alpha:]_][[:alnum:]_]*))*$/)
    end

    def nulls_order(nulls)
      return nil unless nullable?
      return :last if nulls.to_s.downcase == 'last'
      return :first if nulls.to_s.downcase == 'first'

      Rotulus.db.default_nulls_order(direction)
    end

    def primary_key?
      unprefixed_name == model.primary_key
    end
  end
end
