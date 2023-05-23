require 'active_record'
require 'pg'
require 'sqlite3'
require 'mysql2'

if ENV['DB_ADAPTER'] == 'postgresql'
  ActiveRecord::Base.establish_connection(
    adapter: 'postgresql',
    database: 'rotulus',
    host: ENV.fetch('DB_HOST') { 'localhost' },
    username: ENV.fetch('DB_USERNAME') { 'postgres' },
    password: ENV.fetch('DB_PASSWORD') { '' },
    min_messages: 'error'
  )
elsif ENV['DB_ADAPTER'] == 'mysql2'
  ActiveRecord::Base.establish_connection(
    adapter: 'mysql2',
    host: ENV.fetch('DB_HOST') { 'localhost' },
    encoding: 'utf8',
    reconnect: false,
    database: 'rotulus',
    pool: 5,
    username: ENV.fetch('DB_USERNAME') { 'root' },
    password: ENV.fetch('DB_PASSWORD') { '' },
    socket: '/tmp/mysql.sock'
  )
else
  ActiveRecord::Base.establish_connection(
    adapter: 'sqlite3',
    database: ':memory:'
  )
end

module Schema
  def self.create
    ActiveRecord::Migration.verbose = false

    ActiveRecord::Schema.define do
      create_table :users, force: true do |t|
        t.string   :first_name, null: false
        t.string   :last_name
        t.string   :middle_name
        t.string   :email, null: false, index: { unique: true }
        t.string   :ssn, index: { unique: true }
        t.string   :mobile, index: { unique: true }
        t.datetime :member_since
        t.date     :birth_date
        t.boolean  :active
        t.float    :stats
        t.decimal  :balance, precision: 30, scale: 10
        t.bigint   :score
        t.timestamps null: false
      end

      create_table :user_logs, force: true do |t|
        t.string :email, null: false
        t.string :details
      end

      create_table :items, force: true do |t|
        t.string :name, null: false
      end

      create_table :order_items, force: true do |t|
        t.bigint   :item_id, null: false
        t.bigint   :order_id, null: false
        t.bigint   :item_count
      end
    end
  end
end

Schema.create
