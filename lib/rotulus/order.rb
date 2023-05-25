module Rotulus
  class Order
    # Creates an Order object that builds the column objects in the "ORDER BY" expression
    #
    # @param ar_model [Class] the ActiveRecord model class name of Page#ar_relation
    # @param raw_hash [Hash<Symbol, Hash>, Hash<Symbol, Symbol>, nil] the order definition of columns
    #
    def initialize(ar_model, raw_hash = {})
      @ar_model = ar_model
      @raw_hash = raw_hash&.with_indifferent_access || {}
      @definition = {}

      build_column_definitions

      return if has_tiebreaker?
      raise Rotulus::MissingTiebreakerError.new('A non-nullable and distinct column is required.')
    end

    # Returns an array of the ordered columns
    #
    # @return [Array<Rotulus::Column>] ordered columns
    def columns
      @columns ||= definition.values
    end

    # Returns an array of the ordered columns' names
    #
    # @return [Array<String>] ordered column names
    def column_names
      @column_names ||= columns.map(&:name)
    end

    # Returns an array of column names prefixed with table name
    #
    # @return [Array<String>] column names prefixed with the table name
    def prefixed_column_names
      @prefixed_column_names ||= definition.keys.map(&:to_s)
    end

    # Returns the SELECT expressions to include the ordered columns in the selected columns
    # of a query.
    #
    # @return [String] the SELECT expressions
    def select_sql
      columns.map(&:select_sql).join(', ')
    end

    # Returns a hash containing the ordered column values of a given ActiveRecord::Base record
    # instance. These values will be used to generate the query to fetch the preceding/succeeding
    # records of a given :record.
    #
    # @param record [ActiveRecord::Base] a record/row returned from Page#records
    # @return [Hash] the hash containing the column values with the column name as key
    def selected_values(record)
      return {} if record.blank?

      record.slice(*select_aliases)
            .transform_keys do |a|
              Column.select_alias_to_name(a)
            end
    end

    # Returns the reversed `ORDER BY` expression(s) for the current page when the page was accessed
    # via a 'previous' cursor(i.e. navigating back/ page#paged_back?)
    #
    # @return [String] the ORDER BY clause
    def reversed_sql
      Arel.sql(columns_for_order.map(&:reversed_order_sql).join(', '))
    end

    # Returns the ORDER BY sort expression(s) to sort the records
    #
    # @return [String] the ORDER BY clause
    def sql
      Arel.sql(columns_for_order.map(&:order_sql).join(', '))
    end

    # Generate a 'state' so we can detect whether the order definition has changed.
    #
    # @return [String] the hashed state
    def state
      data = Oj.dump(to_h, mode: :rails)

      Digest::MD5.hexdigest("#{data}#{Rotulus.configuration.secret}")
    end

    # Returns a hash containing the hash representation of the ordered columns.
    #
    # @return [Hash] the hash representation of the ordered columns.
    def to_h
      definition.each_with_object({}) do |(name, column), h|
        h.merge!(column.to_h)
      end
    end

    private

    attr_reader :ar_model, :definition, :raw_hash

    def columns_for_order
      return @columns_for_order if instance_variable_defined?(:@columns_for_order)

      @columns_for_order = []
      columns.each do |col|
        @columns_for_order << col

        break if col.distinct? && !col.nullable?
      end

      @columns_for_order
    end

    def ar_model_primary_key
      ar_model.primary_key
    end

    def ar_table
      ar_model.table_name
    end

    def column_model(model_override, name)
      prefix = name.match(/^.*?(?=\.)/).to_s
      unprefixed_name = name.split('.').last

      unless model_override.nil?
        return model_override unless model_override.columns_hash[unprefixed_name].nil?

        raise Rotulus::InvalidColumnError.new(
          "Model '#{model_override}' doesnt have a '#{name}' column. \
          Tip: check the :model option value in the column's order configuration.".squish
        )
      end

      if (prefix.blank? && !ar_model.columns_hash[name].nil?) ||
         (prefix == ar_table && !ar_model.columns_hash[unprefixed_name].nil?)
        return ar_model
      end

      raise Rotulus::InvalidColumnError.new(
        "Unable determine which model the column '#{name}' belongs to. \
        Tip: set/check the :model option value in the column's order configuration.".squish
      )
    end

    def has_tiebreaker?
      last_column = columns_for_order.last

      last_column.distinct? && !last_column.nullable?
    end

    def primary_key_ordered?
      !definition["#{ar_table}.#{ar_model_primary_key}"].nil?
    end

    def build_column_definitions
      raw_hash.each do |column_name, options|
        column_name = column_name.to_s

        unless options.is_a?(Hash)
          options = if options.to_s.downcase == 'desc'
                      { direction: :desc }
                    else
                      { direction: :asc }
                    end
        end

        model = column_model(options[:model].presence, column_name)
        column = Column.new(model,
                            column_name,
                            direction: options[:direction],
                            nulls: options[:nulls],
                            nullable: options[:nullable],
                            distinct: options[:distinct])
        next unless definition[column.prefixed_name].nil?

        definition[column.prefixed_name] = column
      end

      # Add tie-breaker using the PK
      unless primary_key_ordered?
        pk_column = Column.new(ar_model, ar_model_primary_key, direction: :asc)
        definition[pk_column.prefixed_name] = pk_column
      end

      columns.first.as_leftmost!
    end

    # Returns an array of SELECT statement alias of the ordered columns
    #
    # @return [Array<String>] column SELECT aliases
    def select_aliases
      @select_aliases ||= columns.map(&:select_alias)
    end
  end
end
