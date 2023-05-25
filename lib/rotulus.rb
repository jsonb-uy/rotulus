require 'active_record'
require 'active_support'
require 'active_support/core_ext/string/inquiry'
require 'oj'
require 'rotulus/version'
require 'rotulus/configuration'
require 'rotulus/db/database'
require 'rotulus/record'
require 'rotulus/column'
require 'rotulus/column_condition_builder'
require 'rotulus/order'
require 'rotulus/cursor'
require 'rotulus/page_tableizer'
require 'rotulus/page'

module Rotulus
  class BaseError < StandardError; end
  class CursorError < BaseError; end
  class InvalidCursor < CursorError; end
  class ExpiredCursor < CursorError; end
  class InvalidCursorDirection < CursorError; end
  class OrderChanged < CursorError; end
  class QueryChanged < CursorError; end
  class InvalidLimit < BaseError; end
  class ConfigurationError < BaseError; end
  class MissingTiebreakerError < ConfigurationError; end
  class InvalidColumnError < ConfigurationError; end

  def self.db
    @db ||= case ActiveRecord::Base.connection.adapter_name.downcase
            when /(mysql).*/
              require 'rotulus/db/mysql'

              Rotulus::DB::MySQL.new
            when /(postgres).*/
              require 'rotulus/db/postgresql'

              Rotulus::DB::PostgreSQL.new
            else
              require 'rotulus/db/sqlite'

              Rotulus::DB::SQLite.new
            end
  end
end
