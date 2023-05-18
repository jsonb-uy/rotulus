require_relative 'schema'

Schema.create

class User < ActiveRecord::Base
  def self.create_test_data
    User.delete_all
    User.create(email: 'john.doe@email.com', first_name: 'John', last_name: 'Doe')
    User.create(email: 'jane.doe@email.com', first_name: 'Jane', last_name: 'Doe')
    User.create(email: 'jane.c.smith@email.com', first_name: 'Jane', last_name: 'Smith')
    User.create(email: 'rory.gallagher@email.com', first_name: 'Rory', last_name: 'Gallagher')
    User.create(email: 'johnny.apple@email.com', first_name: 'Johnny', last_name: 'Apple')
    User.create(email: 'paul@domain.com', first_name: 'Paul', last_name: nil)
    User.create(email: 'ringo@domain.com', first_name: 'Ringo', last_name: nil)
    User.create(email: 'george@domain.com', first_name: 'George', last_name: nil)
    User.create(email: 'excluded@email.com', first_name: 'Excluded', last_name: 'Record')
  end
end

class UserLog < ActiveRecord::Base
end

User.create_test_data
