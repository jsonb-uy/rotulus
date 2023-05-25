# Rotulus

[![Gem Version](https://badge.fury.io/rb/rotulus.svg)](https://badge.fury.io/rb/rotulus) [![CI](https://github.com/jsonb-uy/rotulus/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/jsonb-uy/rotulus/actions/workflows/ci.yml) [![codecov](https://codecov.io/gh/jsonb-uy/rotulus/branch/main/graph/badge.svg?token=OKGOWP4SH9)](https://codecov.io/gh/jsonb-uy/rotulus)

### Cursor-based pagination for apps built on Rails/ActiveRecord 

Cursor-based pagination is an alternative to OFFSET-based pagination that provides a more stable and predictable pagination behavior as records are being added, updated, and removed in the database through the use of an encoded cursor token.

Some advantages of this approach are:

* Reduces inaccuracies such as duplicate/skipped records due to records being actively manipulated in the DB.
* Can significantly improve performance(with proper DB indexing on ordered columns) especially as you move forward on large datasets. 


## Features

* Sort records by multiple/any number of columns
* Sort records using columns from joined tables
* `NULLS FIRST`/`NULLS LAST` handling
* Allows custom cursor format
* Built-in cursor token expiration
* Built-in cursor integrity checking
* Supports **MySQL**, **PostgreSQL**, and **SQLite**
* Supports **Rails 4.2** and above


## Installation

Add this line to your application's Gemfile:

```ruby
gem 'rotulus'
```

And then execute:

```sh
bundle install
```

Or install it yourself as:

```sh
gem install rotulus
```

## Configuration
Setting the environment variable `ROTULUS_SECRET` to a random string value(e.g. generate via `rails secret`) is the minimum required setup needed. 

<details>
  <summary>**More configuration options**</summary>
  
#### Create an initializer `config/initializers/rotulus.rb`:

  ```ruby
  Rotulus.configure do |config|
    config.page_default_limit = 5
    config.page_max_limit = 50
    config.secret = ENV["MY_ENV_VAR"]
    config.token_expires_in = 10800
    config.cursor_class = MyCursor
    config.restrict_order_change = false
    config.restrict_query_change = false
  end
  ```

| Configuration | Description |
| ----------- | ----------- |
| `page_default_limit` | **Default: 5** <br/> Default record limit per page in case the `:limit` is not given when initializing a page `Rotulus::Page.new(...)` |
| `page_max_limit` | **Default: 50** <br/> Maximum `:limit` value allowed when initializing a page.|
| `secret` | **Default: ENV['ROTULUS_SECRET']** <br/> Key needed to generate the cursor state needed for cursor integrity checking. |
| `token_expires_in` | **Default: 259200**(3 days) <br/> Validity period of a cursor token (in seconds). Set to `nil` to disable token expiration. |
| `restrict_order_change` | **Default: false** <br/> When `true`, raise an `OrderChanged` error when paginating with a token that was generated from a page instance with a different `:order`. <br/> When `false`, no error is raised and pagination is based on the new `:order` definition. |
| `restrict_query_change` | **Default: false** <br/> When `true`, raise a `QueryChanged` error when paginating with a token that was generated from a page instance with a different `:ar_relation` filter/query. <br/> When `false`, no error is raised and pagination will query based on the new `:ar_relation`. |
| `cursor_class` | **Default: Rotulus::Cursor** <br/> Cursor class responsible for encoding/decoding cursor data. Default uses Base64 encoding. see [Custom Token Format](#custom-token-format). |
  <br/>
</details>


## Usage

### Basic Usage

#### Initialize a page

```ruby
users = User.where('age > ?', 16)

page = Rotulus::Page.new(users, order: { id: :asc })
# OR just
page = Rotulus::Page.new(users)
```

###### Example when sorting with multiple columns and `:limit`:

```ruby

page = Rotulus::Page.new(users, order: { first_name: :asc, last_name: :desc }, limit: 3)
```
With the example above, the gem will automatically add the table's PK(`users.id`) in the generated SQL query as the tie-breaker column to ensure stable sorting and pagination.


#### Access the page records

```ruby
page.records
=> [#<User id: 11, first_name: 'John'...]
```

#### Check if a next page exists

```ruby
page.next?
=> true
```
#### Check if a previous page exists

```ruby
page.prev?
=> false
```

#### Get the cursor to access the next page
```ruby
page.next_token
=> "eyI6ZiI6eyJebyI6..."
```
In case there is no next page, `nil` is returned

#### Get the cursor to access the previous page
```ruby
page.prev_token
=> "eyI6ZiI6eyJebyI6..."
```
In case there is no previous page(i.e. currently in first page), `nil` is returned


#### Navigate to the page given a cursor
##### Return a new page instance pointed at the given cursor
```ruby
another_page = page.at('eyI6ZiI6eyJebyI6...')
=> #<Rotulus::Page ..>
```

Or to immediately get the records:

```ruby
page.at(next_page_token).records
```

##### Return the same page instance pointed at the given cursor
```ruby
page.at!('eyI6ZiI6eyJebyI6...')
=> #<Rotulus::Page ..>
```

#### Get the next page
```ruby
next_page = page.next
```
This is the same as `page.at(page.next_token)`. Returns `nil` if there is no next page.

#### Get the previous page
```ruby
previous_page = page.prev
```
This is the same as `page.at(page.prev_token)`. Returns `nil` if there is no previous page.


### Extras
#### Reload page
```ruby
page.reload

# reload then return records
page.reload.records
```

#### Print page in table format for debugging
Currently, only the columns included in `ORDER BY` are shown:

```ruby
puts page.as_table

+------------------------------------------------------------+
|   users.first_name   |   users.last_name   |   users.id    |
+------------------------------------------------------------+
|        George        |       <NULL>        |      1        |
|         Jane         |        Smith        |      3        |
|         Jane         |         Doe         |      2        |
+------------------------------------------------------------+
```

<br/>

### Advanced Usage
#### Expanded order definition
Instead of just specifying the column sorting such as ```{ first_name: :asc }``` in the :order param, one can use the expanded order config in `Hash` format for more sorting options: 

| Column Configuration | Description |
| ----------- | ----------- |
| `direction` | **Default: :asc**. `:asc` or `:desc` |
| `nullable`  | **Default: true** if column is defined as nullable in its table, _false_ otherwise. <br/><br />Whether a null value is expected for this column in the result set. <br /><br/>**Note:** <br/>- Not setting this to _true_ when there are possible rows with NULL values for the specific column in the DB won't return those records. <br/> - In queries with table (outer)`JOIN`s, a column in the result could have a NULL value even if the column doesn't allow nulls in its table. So set `nullable` to _true_ for such cases.
| `nulls` | **Default:**<br/>- MySQL and SQLite: `:first` if `direction` is `:asc`, otherwise `:last`<br/>- PostgreSQL:  `:last` if `direction` is `:asc`, otherwise `:first`<br/><br/>Tells whether rows with NULL column values comes before/after the records with non-null values. Applicable only if column is `nullable`. |
| `distinct` | **Default: true** if the column is the primary key of its table, _false_ otherwise.<br/><br /> Tells whether rows in the result are expected to have unique values for this column. <br/><br />**Note:**<br/>- In queries with table `JOIN`s, multiple rows could have the same column value even if the column has a unique index in its table. So set `distinct` to false for such cases.  |
| `model` | **Default:**<br/> - the model of the base AR relation passed to `Rotulus::Page.new(<ar_relation>)` if column name has no prefix(e.g. `first_name`) and the AR relation model has a column matching the column name.<br/>- the model of the base AR relation passed to `Rotulus::Page.new(<ar_relation>)` if column name has a prefix(e.g. `users.first_name`) and thre prefix matches the AR relation's table name and the table has a column matching the column name. <br/><br/>Model where this column belongs. This allows the gem to infer the nullability and uniqueness from the column definition in its table instead of manually setting the `nullable` or `distinct` options and to also automatically prefix the column name with the table name. <br/>|


##### Example:

```ruby
order = {
  first_name: :asc,
  last_name: {
    direction: :desc,
    nullable: true,
    nulls: :last
  },
  email: {
    distinct: true
  }
}
page = Rotulus::Page.new(users, order: order, limit: 3)

```
<br/>

#### Queries with `JOIN`ed tables
##### Example:

Suppose the requirement is to:<br/>
1. Get all `Item` records.<br/>
2. If an `Item` record has associated `OrderItem` records, get the order ids.<br/>
3. `Item` records with `OrderItem`s should come first.
4. `Item` records with `OrderItem`s should be sorted by `item_count` in descending order. <br/>
5. If multiple rows have the same `item_count` value, sort them by item name in ascending order. <br/>
6. If multiple rows have the same `item_count` value and the same `name`, sort them by `OrderItem` id. <br/>
7. Sort `Item` records with no `OrderItem`, based on the item name in ascending order (tie-breaker). <br/>
8. Sort `Item` records with no `OrderItem` and having the same name by the item id (also tie-breaker).

##### Our solution would be:

```ruby
items = Item.all      # Requirement 1
            .joins("LEFT JOIN order_items oi ON oi.item_id = items.id")  # Requirement 2
            .select('oi.order_id', 'items.*')                            # Requirement 2

order_by = { 
  'oi.item_count' => { 
    direction: :desc,        # Requirement 4
    nulls: :last,            # Requirement 3
    nullable: true,          # Requirement 1
    model: OrderItem 
  }, 
  name: :asc,                  # Requirement 5, 7
  'oi.id' => {
    direction: :asc,         # Requirement 6
    distinct: true,          # Requirement 6
    nullable: true,          # Requirement 1
    model: OrderItem
  },
  id: :asc                    # Requirement 8
}
page = Rotulus::Page.new(items, order: order_by, limit: 2)

```

Some notes for the example above: <br/>
1. `oi.id` is needed to uniquely identify and serve as the tie-breaker for `Item`s that have `OrderItem`s having the same item_count and name.  The combination of `oi.item_count`, `items.name`, and `oi.id` makes those record unique in the dataset. <br/>
2. `id` is translated to `items.id` and is needed to uniquely identify and serve as the tie-breaker for `Item`s that have NO `OrderItem`s. The combination of `oi.item_count`(NULL), `items.name`, `oi.id`(NULL), and `items.id` makes those record unique in the dataset. Although, this can be removed in the configuration above as the `Item` table's primary key will be automatically added as the last `ORDER BY` column if it isn't included yet.<br/>
3. Explicitly setting the `model: OrderItem` in joined table columns is required for now.  

An alternate solution that would also avoid N+1 if the `OrderItem` instances are to be accessed:

```ruby
items = Item.all                       # Requirement 1
            .eager_load(:order_items)  # Requirement 2

order_by = { 
  item_count: { 
    direction: :desc,        # Requirement 4
    nulls: :last,            # Requirement 3
    nullable: true,          # Requirement 1
    model: OrderItem 
  }, 
  name: :asc,                # Requirement 5, 7
  'order_items.id' => {
    direction: :asc,         # Requirement 6
    distinct: true,          # Requirement 6
    nullable: true,          # Requirement 1
    model: OrderItem
  }
}
page = Rotulus::Page.new(items, order: order_by, limit: 2)

```

<br/>

### Errors

| Class | Description |
| ----------- | ----------- |
| `Rotulus::InvalidCursor` | Cursor token received is invalid e.g., unrecognized token, token data has been tampered/updated. |
| `Rotulus::Expired` | Cursor token received has expired based on the configured `token_expires_in` |
| `Rotulus::InvalidLimit` | Limit set to Rotulus::Page is not valid. e.g., exceeds the configured limit. see `config.page_max_limit` |
| `Rotulus::CursorError` | Generic error for cursor related validations |
| `Rotulus::InvalidColumn` | Column provided in the :order param can't be found. |
| `Rotulus::MissingTiebreaker` | There is no non-nullable and distinct column in the configured order definition. |
| `Rotulus::ConfigurationError` | Generic error for missing/invalid configurations. |
| `Rotulus::OrderChanged` | Error raised paginating with a token(i.e. calling `Page#at` or `Page#at!`) that was generated from a previous page instance with a different `:order` definition. Can be enabled by setting the `restrict_order_change` to true. |
| `Rotulus::QueryChanged` | Error raised paginating with a token(i.e. calling `Page#at` or `Page#at!`) that was generated from a previous page instance with a different `:ar_relation` filter/query. Can be enabled by setting the `restrict_query_change` to true. |

## How it works
Cursor-based pagination uses a reference point/record to fetch the previous or next set of records. This gem takes care of the SQL query and cursor generation needed for the pagination. To ensure that the pagination results are stable, it requires that:

* Records are sorted (`ORDER BY`).
* In case multiple records with the same column value(s) exists in the result, a unique non-nullable column is needed as tie-breaker. Usually, the table PK suffices for this but for complex queries(e.g. with table joins and with nullable columns, etc.), combining and using multiple columns that would uniquely identify the row in the result is needed.
* Columns used in `ORDER BY` would need to be indexed as they will be used in filtering.


#### Sample SQL generated snippets

##### Example 1: With order by `id` only
###### Ruby
```ruby
page = Rotulus::Page.new(User.all, limit: 3)
```

###### SQL:
```sql
WHERE 
  users.id > ?
ORDER BY
  users.id asc LIMIT 3
```

##### Example 2: With non-distinct and not nullable column `first_name`
###### Ruby
```ruby
page = Rotulus::Page.new(User.all, order: { first_name: :asc }, limit: 3)
```

###### SQL:
```sql
WHERE
  users.first_name >= ? AND
  (users.first_name > ? OR
    (users.first_name = ? AND
     users.id > ?))
ORDER BY
  users.first_name asc,
  users.id asc LIMIT 3
```

##### Example 3: With non-distinct and nullable(nulls last) column `last_name`
###### Ruby
```ruby
page = Rotulus::Page.new(User.all, order: { first_name: { direction: :asc, nulls: :last }}, limit: 3)
```

###### SQL:
```sql
-- if last_name value of the current page's last record  is not null:
WHERE ((users.last_name >= ? OR users.last_name IS NULL) AND
  ((users.last_name > ? OR users.last_name IS NULL) 
  OR (users.last_name = ? AND users.id > ?)))
ORDER BY users.last_name asc nulls last, users.id asc LIMIT 3

-- if last_name value of the current page's last record is null:
WHERE users.last_name IS NULL AND users.id > ?
ORDER BY users.last_name asc nulls last, users.id asc LIMIT 3
```


### Cursor
To navigate between pages, a cursor is used. The cursor token is a Base64 encoded string containing the data on how to filter the next/previous page's records. A decoded cursor to access the next page would look like:

#### Decoded Cursor

```json
{
  "f": { "users.first_name": "Jane", "users.id": 2 }, 
  "d": "next",
  "c": 1672502400,
  "cs": "fe6ac1a1d6a1fc1b7f842b388639f63b",
  "os": "62186497a8073f9c7072389b73c6c60c",
  "qs": "7a5053198709df924dd5ec1752ee4e6b"
}
```
1. `f` - contains the record values from the last record of the current page. Only the columns included in the `ORDER BY` are included. Note also that the unique column `users.id` is included as a tie-breaker.
2. `d` - the pagination direction. `next` or `prev` set of records from the reference values in "f".
3. `cs` - the cursor state needed for integrity checking, restrict clients/third-parties from generating their own (unsafe)tokens, or from tampering the data of an existing token. 
4. `os` - the order state needed to detect whether the order definition changed.
5. `qs` - the base AR relation state neede to detect whether the ar_relation has changed (e.g. filter/query changed due to API params). 
4. `c` -  cursor token issuance time.

A condition generated from the cursor above would look like:

```sql
WHERE users.first_name >= 'Jane' AND (
  users.first_name > 'Jane' OR (
    users.first_name = 'Jane' AND (users.id > 2)
  )
) LIMIT N
```

#### Custom Token Format
By default, the cursor is encoded as a Base64 token. To customize how the cursor is encoded and decoded, you may just create a subclass of `Rotulus::Cursor` with `.decode` and `.encode` methods implemented.

##### Example:
The implementation below would generate tokens in UUID format where the actual cursor data is stored in memory:

```ruby
class MyCustomCursor < Rotulus::Cursor
  def self.decode(token)
    data = storage[token]
    return data if data.present?

    raise Rotulus::InvalidCursor
  end

  def self.encode(data)
    storage_key = SecureRandom.uuid

    storage[storage_key] = data
    storage_key
  end

  def self.storage
    @storage ||= {}
  end
end
```

###### config/initializers/rotulus.rb
```ruby
Rotulus.configure do |config|
  ...
  config.cursor_class = MyCustomCursor
end
```
<br/>

### Limitations
1. Custom SQL in `ORDER BY` expression other than sorting by table column values aren't supported to leverage the index usage.
2. `ORDER BY` column names with characters other than alphanumeric and underscores are not supported.

### Considerations
1. Although adding indexes improves DB read performance, it can impact write performance. Only expose/whitelist the columns that are really needed in sorting.
2. Depending on your use case, a disadvantage is that cursor-based pagination does not allow jumping to a specific page (no page numbers).


## Development

1. If testing/developing for MySQL or PG, create the database first:<br/>

  ###### MySQL
  ```sh
  mysql> CREATE DATABASE rotulus;
  ```

  ###### PostgreSQL
  ```sh
  $ createdb rotulus
  ```

2. After checking out the repo, run `bin/setup` to install dependencies.
3. Run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment. Use the environment variables below to target the database<br/><br/>
  
  By default, SQLite and the latest stable Rails version are used in tests and console. Refer to the environment variables below to change this:

  | Environment Variable | Values | Example |
  | ----------- | ----------- |----------- |
  | `DB_ADAPTER` | **Default: :sqlite**. `sqlite`,`mysql2`, or `postgresql` | ```DB_ADAPTER=postgresql bundle exec rspec```<br/><br/> ```DB_ADAPTER=postgresql ./bin/console``` |
  | `RAILS_VERSION` | **Default: 7-0** <br/><br/> `4-2`,`5-0`,`5-1`,`5-2`,`6-0`,`6-1`,`7-0` |```RAILS_VERSION=5-2 ./bin/setup```<br/><br/>```RAILS_VERSION=5-2 bundle exec rspec```<br/><br/> ```RAILS_VERSION=5-2 ./bin/console```|


<br/><br/>
To install this gem onto your local machine, run `bundle exec rake install`.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/jsonb-uy/rotulus.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
