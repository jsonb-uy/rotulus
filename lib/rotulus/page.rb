module Rotulus
  class Page
    attr_reader :ar_relation, :order, :limit, :cursor

    delegate :columns, to: :order, prefix: true

    # Creates a new Page instance representing a subset of the given ActiveRecord::Relation
    # records sorted using the given 'order' definition param.
    #
    # @param ar_relation [ActiveRecord::Relation] the base relation instance to be paginated
    # @param order [Hash<Symbol, Hash>, Hash<Symbol, Symbol>, nil] the order definition of columns.
    #   Same with SQL 'ORDER BY', columns listed first takes precedence in the sorting of records.
    #   The order param allows 2 formats: expanded and compact. Expanded format exposes some config
    #   which allows more control in generating the optimal SQL queries to filter page records.
    #
    #   Available options for each column in expanded order definition:
    #   * direction (Symbol) the sort direction, +:asc+ or +:desc+. Default: +:asc+.
    #   * nullable (Boolean) whether a null value is expected for this column in the query result.
    #     Note that for queries with table JOINs, a column could have a null value
    #     even if the column doesn't allow nulls in its table so :nullable might need to be set to
    #     +true+ for such cases.
    #     Default: +true+ if :nullable option value is nil and the
    #     column is defined as nullable in its table otherwise, false.
    #   * nulls (Symbol) null values sorting, +:first+ for +NULLS FIRST+ and
    #     +:last+ for +NULLS LAST+. Applicable only if column is :nullable.
    #   * distinct (Boolean) whether the column value is expected to be unique in the result.
    #     Note that for queries with table JOINs, multiple rows could have the same column
    #     value even if the column has a unique index defined in its table so :distinct might
    #     need to be set to +false+ for such cases.
    #     Default: true if :distinct option value is nil and the column is the PK of its
    #     table otherwise, false.
    #   * model (Class) Model where the column belongs to.
    #
    # @param limit [Integer] the number of records per page. Defaults to the +config.page_default_limit+.
    #
    # @example Using expanded order definition (Recommended)
    #  Rotulus::Page.new(User.all, order: { last_name: { direction: :asc },
    #                              first_name: { direction: :desc, nulls: :last },
    #                              ssn: { direction: :asc, distinct: true } }, limit: 3)
    #
    # @example Using compact order definition
    #  Rotulus::Page.new(User.all, order: { last_name: :asc, first_name: :desc, ssn: :asc }, limit: 3)
    #
    # @raise [InvalidLimit] if the :limit exceeds the configured :page_max_limit or if the
    #  :limit is not a positive number.
    def initialize(ar_relation, order: { id: :asc }, limit: nil)
      unless limit_valid?(limit)
        raise InvalidLimit.new("Allowed page limit is 1 up to #{config.page_max_limit}")
      end

      @ar_relation = ar_relation || model.none
      @order = Order.new(model, order)
      @limit = (limit.presence || config.page_default_limit).to_i
    end

    # Return a new page pointed to the given cursor(in encoded token format)
    #
    # @param token [String] Base64-encoded representation of cursor.
    #
    # @example
    #   page = Rotulus::Page.new(User.where(last_name: 'Doe'), order: { first_name: :desc }, limit: 2)
    #   page.at('eyI6ZiI6eyJebyI6IkFjdGl2ZVN1cHBvcnQ6Okhhc2hXaXRoSW5kaWZm...')
    #
    # @return [Page] page instance
    def at(token)
      page_copy = dup
      page_copy.at!(token)
      page_copy
    end

    # Point the same page instance to the given cursor(in encoded token format)
    #
    # @example
    #   page = Rotulus::Page.new(User.where(last_name: 'Doe'), order: { first_name: :desc }, limit: 2)
    #   page.at!('eyI6ZiI6eyJebyI6IkFjdGl2ZVN1cHBvcnQ6Okhhc2hXaXRoSW5kaWZm...')
    #
    # @param token [String] Base64-encoded representation of cursor
    # @return [self] page instance
    def at!(token)
      @cursor = token.present? ? cursor_clazz.for_page_and_token!(self, token) : nil

      reload
    end

    # Get the records for this page. Note an extra record is fetched(limit + 1)
    # to make it easier to check whether a next or previous page exists.
    #
    # @return [Array<ActiveRecord::Base>] array of records for this page.
    def records
      return loaded_records[1..limit] if paged_back? && extra_row_returned?

      loaded_records[0...limit]
    end

    # Clear memoized records to lazily force to initiate the query again.
    #
    # @return [self] page instance
    def reload
      @loaded_records = nil

      self
    end

    # Check if a next page exists
    #
    # @return [Boolean] returns true if a next page exists, otherwise returns false.
    def next?
      ((cursor.nil? || paged_forward?) && extra_row_returned?) || paged_back?
    end

    # Check if a preceding page exists
    #
    # @return [Boolean] returns true if a previous page exists, otherwise returns false.
    def prev?
      (paged_back? && extra_row_returned?) || !cursor.nil? && paged_forward?
    end

    # Check if the page is the 'root' page; meaning, there are no preceding pages.
    #
    # @return [Boolean] returns true if the page is the root page, otherwise false.
    def root?
      cursor.nil? || !prev?
    end

    # Generate the cursor token to access the next page if one exists
    #
    # @return [String] Base64-encoded representation of cursor
    def next_token
      return unless next?

      record = cursor_reference_record(:next)
      return if record.nil?

      cursor_clazz.new(record, :next).to_token
    end

    # Generate the cursor token to access the previous page if one exists
    #
    # @return [Cursor] Base64-encoded representation of cursor
    def prev_token
      return unless prev?

      record = cursor_reference_record(:prev)
      return if record.nil?

      cursor_clazz.new(record, :prev).to_token
    end

    # Next page instance
    #
    # @return [Page] the next page with records after the last record of this page.
    def next
      return unless next?

      at next_token
    end

    # Previous page instance
    #
    # @return [Page] the previous page with records preceding the first record of this page.
    def prev
      return unless prev?

      at prev_token
    end

    # Generate a hash containing the previous and next page cursor tokens
    #
    # @return [Hash] the hash containing the cursor tokens
    def links
      return {} if records.empty?

      {
        previous: prev_token,
        next: next_token
      }.delete_if { |_, token| token.nil? }
    end

    # Return Hashed value of this page's state so we can check whether the ar_relation's filter and
    # order definition are still consistent to the cursor. see Cursor.state_valid?.
    #
    # @return [String] the hashed state
    def state
      Digest::MD5.hexdigest("#{ar_relation.to_sql}~#{order.state}")
    end

    # Returns a string showing the page's records in table form with the ordered columns
    # as the columns. This method is primarily used to test/debug the pagination behavior.
    #
    # @return [String] table
    def as_table
      Rotulus::PageTableizer.new(self).tableize
    end

    def inspect
      cursor_info = cursor.nil? ? '' : " cursor='#{cursor}'"

      "#<#{self.class.name} ar_relation=#{ar_relation} order=#{order} limit=#{limit}#{cursor_info}>"
    end

    private

    # If this is the root page or when paginating forward(#paged_forward), limit+1
    # includes the first record of the next page. This lets us know whether there is a page
    # succeeding the current page. When paginating backwards(#paged_back?), the limit+1 includes the
    # record prior to the current page's first record(last record of the previous page, if it exists)
    # -letting us know that the current page has a previous/preceding page.
    def loaded_records
      return @loaded_records unless @loaded_records.nil?

      @loaded_records = ar_relation.where(cursor&.sql)
                                   .reorder(order_by_sql)
                                   .limit(limit + 1)
                                   .select(*select_columns)
      return @loaded_records.to_a unless paged_back?

      # Reverse the returned records in case #paged_back? as the sorting is also reversed.
      @loaded_records = @loaded_records.reverse
    end

    # Query in #loaded_records uses limit + 1. Returns true if an extra row was retrieved.
    def extra_row_returned?
      loaded_records.size > limit
    end

    def paged_back?
      !!cursor&.prev?
    end

    def paged_forward?
      !!cursor&.next?
    end

    def cursor_reference_record(direction)
      record = direction == :next ? records.last : records.first

      Record.new(self, order.selected_values(record))
    end

    # SELECT the ordered columns so we can use the values to generate the 'where' condition
    # to filter next/prev page's records. Alias and normalize those columns so we can access
    # the values using record#slice.
    def select_columns
      base_select_values = ar_relation.select_values.presence || [select_all_sql]
      base_select_values << order.select_sql
      base_select_values
    end

    def select_all_sql
      Rotulus.db.select_all_sql(model.table_name)
    end

    def order_by_sql
      return order.reversed_sql if paged_back?

      order.sql
    end

    def limit_valid?(limit)
      return true if limit.blank?

      limit = limit.to_i
      limit >= 1 && limit <= config.page_max_limit
    end

    def model
      ar_relation.model
    end

    def config
      @config ||= Rotulus.configuration
    end

    def cursor_clazz
      @cursor_clazz ||= config.cursor_class
    end
  end
end
