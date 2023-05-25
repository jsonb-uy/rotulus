module Rotulus
  class Configuration
    attr_accessor :secret

    def initialize
      @page_default_limit = default_limit
      @page_max_limit = default_max_limit
      @secret = ENV['ROTULUS_SECRET']
      @token_expires_in = 259_200
      @cursor_class = default_cursor_class
      @restrict_order_change = false
      @restrict_query_change = false
    end

    def page_default_limit=(limit)
      @page_default_limit = limit.to_i
    end

    def page_default_limit
      limit = @page_default_limit
      limit = default_limit unless limit.positive?
      limit = page_max_limit if limit > page_max_limit
      limit
    end

    def page_max_limit=(limit)
      @page_max_limit = limit.to_i
    end

    def page_max_limit
      return @page_max_limit if @page_max_limit.positive?

      default_max_limit
    end

    def token_expires_in=(expire_in_seconds)
      @token_expires_in = expire_in_seconds.to_i
    end

    def token_expires_in
      return @token_expires_in if @token_expires_in.positive?

      nil
    end

    def cursor_class=(cursor_class)
      @cursor_class = cursor_class.is_a?(String) ? cursor_class.constantize : cursor_class
    end

    def cursor_class
      @cursor_class || default_cursor_class
    end

    def restrict_order_change=(restrict)
      @restrict_order_change = !!restrict
    end

    def restrict_order_change?
      @restrict_order_change
    end

    def restrict_query_change=(restrict)
      @restrict_query_change = !!restrict
    end

    def restrict_query_change?
      @restrict_query_change
    end

    private

    def default_cursor_class
      Rotulus::Cursor
    end

    def default_limit
      5
    end

    def default_max_limit
      50
    end
  end

  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.configure
    yield configuration if block_given?
  end
end
